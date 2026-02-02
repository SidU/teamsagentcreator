<#
.SYNOPSIS
    Removes an Azure Bot and its associated App Registration.

.PARAMETER BotName
    The name of the bot to remove.

.PARAMETER ResourceGroupName
    The resource group containing the bot.

.PARAMETER KeepAppRegistration
    If specified, keeps the Azure AD App Registration (only deletes the Bot Service).

.PARAMETER Force
    Skip confirmation prompt.

.EXAMPLE
    .\Remove-TeamsBot.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG"

.EXAMPLE
    .\Remove-TeamsBot.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BotName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [switch]$KeepAppRegistration,

    [switch]$Force
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

# Confirmation
if (-not $Force) {
    Write-Host ""
    Write-Host "This will delete:" -ForegroundColor Yellow
    Write-Host "  - Azure Bot Service: $BotName" -ForegroundColor White
    if (-not $KeepAppRegistration) {
        Write-Host "  - Azure AD App Registration: $appId" -ForegroundColor White
    }
    Write-Host ""
    $confirm = Read-Host "Are you sure? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "[INFO] Cancelled" -ForegroundColor Gray
        exit 0
    }
}

# Delete the Bot Service
Write-Host "[INFO] Deleting Azure Bot Service..." -ForegroundColor Cyan
Remove-AzResource `
    -ResourceGroupName $ResourceGroupName `
    -ResourceType "Microsoft.BotService/botServices" `
    -ResourceName $BotName `
    -ApiVersion "2022-09-15" `
    -Force

Write-Host "[SUCCESS] Bot Service deleted" -ForegroundColor Green

# Delete the App Registration
if (-not $KeepAppRegistration) {
    Write-Host "[INFO] Deleting Azure AD App Registration..." -ForegroundColor Cyan

    $app = Get-AzADApplication -Filter "appId eq '$appId'" -ErrorAction SilentlyContinue
    if ($app) {
        Remove-AzADApplication -ObjectId $app.Id
        Write-Host "[SUCCESS] App Registration deleted" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] App Registration not found (may have been deleted already)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[SUCCESS] Bot '$BotName' has been removed" -ForegroundColor Green
