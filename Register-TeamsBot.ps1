<#
.SYNOPSIS
    Registers a new bot in Microsoft Azure and enables it for Microsoft Teams.

.DESCRIPTION
    This script creates:
    - An Azure AD App Registration (bot identity)
    - An Azure Bot Service resource (SingleTenant)
    - Enables the Microsoft Teams channel
    - Adds Microsoft Graph User.Read.All permission (for OpenClaw.ai integration)
    - Grants admin consent for the permissions

    It outputs the App ID and Secret needed to configure your bot.

.PARAMETER BotName
    The name for your bot (used for both the Azure Bot and App Registration).
    Must be globally unique.

.PARAMETER ResourceGroupName
    The Azure Resource Group to create the bot in. Will be created if it doesn't exist.

.PARAMETER MessagingEndpoint
    The HTTPS URL where your bot receives messages (e.g., https://mybot.azurewebsites.net/api/messages)

.PARAMETER Location
    Azure region for the resource group. Default is "westus".

.PARAMETER SubscriptionId
    Optional. The Azure subscription ID to use. If not provided, uses the current context.

.PARAMETER SkipGraphPermissions
    Optional. Skip adding Microsoft Graph permissions (User.Read.All).

.EXAMPLE
    .\Register-TeamsBot.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG" -MessagingEndpoint "https://mybot.azurewebsites.net/api/messages"

.EXAMPLE
    .\Register-TeamsBot.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG" -MessagingEndpoint "https://mybot.ngrok.io/api/messages" -Location "eastus"

.OUTPUTS
    PSCustomObject with AppId, AppSecret, BotName, and ResourceGroup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z][a-zA-Z0-9-]{2,35}$')]
    [string]$BotName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://')]
    [string]$MessagingEndpoint,

    [Parameter(Mandatory = $false)]
    [string]$Location = "westus",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [switch]$SkipGraphPermissions
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

# Check for Az module
Write-Status "Checking for Az PowerShell module..."
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Status "Az module not found. Installing..." "WARNING"
    Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber
}

# Import required modules
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Resources -ErrorAction Stop

# Check if logged in
$context = Get-AzContext
if (-not $context) {
    Write-Status "Not logged into Azure. Initiating login..." "WARNING"
    Connect-AzAccount
    $context = Get-AzContext
}

Write-Status "Logged in as: $($context.Account.Id)" "SUCCESS"

# Set subscription if provided
if ($SubscriptionId) {
    Write-Status "Setting subscription to: $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
}

Write-Status "Using subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"

# Create or verify resource group
Write-Status "Checking resource group: $ResourceGroupName"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Status "Creating resource group: $ResourceGroupName in $Location"
    $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Status "Resource group created" "SUCCESS"
} else {
    Write-Status "Resource group already exists" "SUCCESS"
}

# Create Azure AD App Registration
Write-Status "Creating Azure AD App Registration: $BotName"

# Check if app already exists
$existingApp = Get-AzADApplication -DisplayName $BotName -ErrorAction SilentlyContinue
if ($existingApp) {
    Write-Status "App registration '$BotName' already exists. Use a different name or delete the existing one." "ERROR"
    throw "App registration already exists"
}

$app = New-AzADApplication -DisplayName $BotName
Write-Status "App Registration created with ID: $($app.AppId)" "SUCCESS"

# Create client secret (valid for 2 years)
Write-Status "Creating client secret..."
$endDate = (Get-Date).AddYears(2)
$secret = New-AzADAppCredential -ObjectId $app.Id -EndDate $endDate

# Small delay to ensure secret is propagated
Start-Sleep -Seconds 2

Write-Status "Client secret created (expires: $endDate)" "SUCCESS"

# Add Microsoft Graph permissions (User.Read.All) for OpenClaw.ai integration
if (-not $SkipGraphPermissions) {
    Write-Status "Adding Microsoft Graph User.Read.All permission..."

    # Microsoft Graph API App ID (constant)
    $graphApiId = "00000003-0000-0000-c000-000000000000"
    # User.Read.All Application permission ID
    $userReadAllId = "df021288-bdef-4463-88db-98f22de89214"

    try {
        # Add the permission requirement to the app
        $graphPermission = @{
            resourceAppId = $graphApiId
            resourceAccess = @(
                @{
                    id = $userReadAllId
                    type = "Role"  # "Role" = Application permission, "Scope" = Delegated
                }
            )
        }

        # Update the app with the required permissions
        Update-AzADApplication -ObjectId $app.Id -RequiredResourceAccess $graphPermission
        Write-Status "Microsoft Graph User.Read.All permission added" "SUCCESS"

        # Grant admin consent using Azure CLI (more reliable for this operation)
        Write-Status "Granting admin consent for Microsoft Graph permissions..."

        # Create a service principal for the app if it doesn't exist
        $sp = Get-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction SilentlyContinue
        if (-not $sp) {
            $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
            Start-Sleep -Seconds 3
        }

        # Use az cli to grant admin consent (PowerShell Az module doesn't have a direct cmdlet for this)
        $grantResult = az ad app permission admin-consent --id $app.AppId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Admin consent granted for Microsoft Graph permissions" "SUCCESS"
        } else {
            Write-Status "Could not auto-grant admin consent. Please grant manually in Azure Portal:" "WARNING"
            Write-Status "  Azure Portal > App registrations > $BotName > API permissions > Grant admin consent" "WARNING"
        }
    } catch {
        Write-Status "Failed to add Graph permissions: $_" "WARNING"
        Write-Status "You may need to add User.Read.All permission manually in Azure Portal" "WARNING"
    }
}

# Create the Azure Bot resource
Write-Status "Creating Azure Bot Service: $BotName"

$botProperties = @{
    displayName         = $BotName
    endpoint            = $MessagingEndpoint
    msaAppId            = $app.AppId
    msaAppType          = "SingleTenant"
    msaAppTenantId      = $context.Tenant.Id
    developerAppInsightsApplicationId = ""
    developerAppInsightKey = ""
    disableLocalAuth    = $false
    schemaTransformationVersion = "1.3"
}

try {
    $bot = New-AzResource `
        -ResourceGroupName $ResourceGroupName `
        -ResourceType "Microsoft.BotService/botServices" `
        -ResourceName $BotName `
        -Location "global" `
        -Properties $botProperties `
        -ApiVersion "2022-09-15" `
        -Force

    Write-Status "Azure Bot Service created" "SUCCESS"
} catch {
    Write-Status "Failed to create bot service: $_" "ERROR"
    # Cleanup: remove the app registration
    Write-Status "Cleaning up app registration..."
    Remove-AzADApplication -ObjectId $app.Id -ErrorAction SilentlyContinue
    throw
}

# Enable Microsoft Teams channel
Write-Status "Enabling Microsoft Teams channel..."

$teamsChannelProperties = @{
    channelName = "MsTeamsChannel"
    properties  = @{
        isEnabled = $true
    }
}

try {
    $teamsChannel = New-AzResource `
        -ResourceGroupName $ResourceGroupName `
        -ResourceType "Microsoft.BotService/botServices/channels" `
        -ResourceName "$BotName/MsTeamsChannel" `
        -Location "global" `
        -Properties $teamsChannelProperties `
        -ApiVersion "2022-09-15" `
        -Force

    Write-Status "Microsoft Teams channel enabled" "SUCCESS"
} catch {
    Write-Status "Failed to enable Teams channel: $_" "WARNING"
    Write-Status "You may need to enable Teams channel manually in Azure Portal"
}

# Output results
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BOT REGISTRATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Bot Name:           $BotName" -ForegroundColor White
Write-Host "Resource Group:     $ResourceGroupName" -ForegroundColor White
Write-Host "Messaging Endpoint: $MessagingEndpoint" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  CREDENTIALS (SAVE THESE SECURELY!)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "App ID (MicrosoftAppId):     $($app.AppId)" -ForegroundColor Cyan
Write-Host "App Secret (MicrosoftAppPassword): $($secret.SecretText)" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host ""
Write-Status "Add these to your bot's configuration (appsettings.json, .env, etc.)" "INFO"

# Return object for programmatic use
$result = [PSCustomObject]@{
    BotName        = $BotName
    ResourceGroup  = $ResourceGroupName
    Endpoint       = $MessagingEndpoint
    AppId          = $app.AppId
    AppSecret      = $secret.SecretText
    TenantId       = $context.Tenant.Id
    SubscriptionId = $context.Subscription.Id
}

return $result
