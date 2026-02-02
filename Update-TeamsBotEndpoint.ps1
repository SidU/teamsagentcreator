<#
.SYNOPSIS
    Updates the messaging endpoint URL for an existing Azure Bot.

.PARAMETER BotName
    The name of the existing bot.

.PARAMETER ResourceGroupName
    The resource group containing the bot.

.PARAMETER MessagingEndpoint
    The new HTTPS URL for the bot's messaging endpoint.

.EXAMPLE
    .\Update-TeamsBotEndpoint.ps1 -BotName "my-teams-bot" -ResourceGroupName "MyBotRG" -MessagingEndpoint "https://newurl.azurewebsites.net/api/messages"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BotName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://')]
    [string]$MessagingEndpoint
)

$ErrorActionPreference = "Stop"

# Check login
$context = Get-AzContext
if (-not $context) {
    Write-Host "[WARNING] Not logged into Azure. Initiating login..." -ForegroundColor Yellow
    Connect-AzAccount
}

Write-Host "[INFO] Fetching bot: $BotName" -ForegroundColor Cyan

# Get current bot
$bot = Get-AzResource `
    -ResourceGroupName $ResourceGroupName `
    -ResourceType "Microsoft.BotService/botServices" `
    -ResourceName $BotName `
    -ApiVersion "2022-09-15"

if (-not $bot) {
    Write-Host "[ERROR] Bot not found: $BotName in $ResourceGroupName" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Current endpoint: $($bot.Properties.endpoint)" -ForegroundColor Gray
Write-Host "[INFO] Updating to: $MessagingEndpoint" -ForegroundColor Cyan

# Update the endpoint
$bot.Properties.endpoint = $MessagingEndpoint

$updated = Set-AzResource `
    -ResourceId $bot.ResourceId `
    -Properties $bot.Properties `
    -ApiVersion "2022-09-15" `
    -Force

Write-Host "[SUCCESS] Messaging endpoint updated!" -ForegroundColor Green
Write-Host ""
Write-Host "Bot Name: $BotName" -ForegroundColor White
Write-Host "New Endpoint: $MessagingEndpoint" -ForegroundColor Cyan
