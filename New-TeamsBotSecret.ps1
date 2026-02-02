<#
.SYNOPSIS
    Generates a new client secret for an existing Azure Bot.

.DESCRIPTION
    Creates a new client secret for the bot's App Registration.
    The old secret(s) remain valid until they expire or are manually removed.

.PARAMETER BotName
    The name of the bot.

.PARAMETER ResourceGroupName
    The resource group containing the bot.

.PARAMETER ValidityYears
    How many years the new secret should be valid. Default is 2.

.EXAMPLE
    .\New-TeamsBotSecret.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG"

.EXAMPLE
    .\New-TeamsBotSecret.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG" -ValidityYears 1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BotName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5)]
    [int]$ValidityYears = 2
)

$ErrorActionPreference = "Stop"

# Check login
$context = Get-AzContext
if (-not $context) {
    Write-Host "[WARNING] Not logged into Azure. Initiating login..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Get the bot to find the App ID
Write-Host "[INFO] Looking up bot: $BotName" -ForegroundColor Cyan

$bot = Get-AzResource `
    -ResourceGroupName $ResourceGroupName `
    -ResourceType "Microsoft.BotService/botServices" `
    -ResourceName $BotName `
    -ApiVersion "2022-09-15" `
    -ErrorAction SilentlyContinue

if (-not $bot) {
    Write-Host "[ERROR] Bot not found: $BotName in $ResourceGroupName" -ForegroundColor Red
    exit 1
}

$appId = $bot.Properties.msaAppId
Write-Host "[INFO] Found bot with App ID: $appId" -ForegroundColor Gray

# Get the App Registration
$app = Get-AzADApplication -Filter "appId eq '$appId'"
if (-not $app) {
    Write-Host "[ERROR] App Registration not found for App ID: $appId" -ForegroundColor Red
    exit 1
}

# Create new secret
Write-Host "[INFO] Creating new client secret..." -ForegroundColor Cyan
$endDate = (Get-Date).AddYears($ValidityYears)
$secret = New-AzADAppCredential -ObjectId $app.Id -EndDate $endDate

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  NEW SECRET CREATED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Bot Name:    $BotName" -ForegroundColor White
Write-Host "App ID:      $appId" -ForegroundColor Cyan
Write-Host "New Secret:  $($secret.SecretText)" -ForegroundColor Cyan
Write-Host "Expires:     $endDate" -ForegroundColor Gray
Write-Host ""
Write-Host "[WARNING] Old secrets are still valid. Remove them manually if needed." -ForegroundColor Yellow
Write-Host ""

# Return for programmatic use
return [PSCustomObject]@{
    BotName   = $BotName
    AppId     = $appId
    AppSecret = $secret.SecretText
    ExpiresOn = $endDate
}
