# Agent Instructions: Teams Bot Registration

This folder contains scripts to register a Microsoft Teams bot in Azure and create a sideloadable app package.

## Workflow

When a user asks to create/register a Teams bot for OpenClaw.ai or similar, follow these steps:

### 1. Gather Required Information

Ask the user for:
- **Bot name**: A unique name for the bot (alphanumeric + hyphens, 3-36 chars)
- **Resource group name**: Azure resource group (will be created if it doesn't exist)
- **Messaging endpoint**: The HTTPS callback URL where the bot receives messages (e.g., `https://example.trycloudflare.com/api/messages`)

### 2. Ensure Azure CLI is Installed

Check if `az` command is available:
```bash
which az
```

If not installed, install via Homebrew (macOS):
```bash
brew install azure-cli
```

### 3. Ensure User is Logged into Azure

```bash
az account show
```

If not logged in, run:
```bash
az login
```

### 4. Run the Registration Script

Use the bash script (preferred if `az` CLI is available):
```bash
./register-teams-bot.sh <bot-name> <resource-group> <messaging-endpoint>
```

Or PowerShell (if `pwsh` is available):
```powershell
.\Register-TeamsBot.ps1 -BotName "<bot-name>" -ResourceGroupName "<resource-group>" -MessagingEndpoint "<messaging-endpoint>"
```

The script will:
- Create an Azure AD App Registration
- Generate a client secret
- Add Microsoft Graph `User.Read.All` permission
- Grant admin consent for the tenant
- Create the Azure Bot Service (SingleTenant)
- Enable the Microsoft Teams channel

**Important**: Capture and display the credentials to the user:
- App ID (MicrosoftAppId)
- App Secret (MicrosoftAppPassword)
- Tenant ID (MicrosoftAppTenantId)

### 5. Create the Teams App Package

After registration, create a Teams app manifest for sideloading:

#### a. Create a directory for the app package
```bash
mkdir -p teams-app
```

#### b. Create `manifest.json`

Use this template, replacing `<APP_ID>`, `<BOT_NAME>`, and `<ENDPOINT_DOMAIN>`:

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.17/MicrosoftTeams.schema.json",
  "manifestVersion": "1.17",
  "version": "1.0.0",
  "id": "<APP_ID>",
  "developer": {
    "name": "Developer",
    "websiteUrl": "https://example.com",
    "privacyUrl": "https://example.com/privacy",
    "termsOfUseUrl": "https://example.com/terms"
  },
  "name": {
    "short": "<BOT_NAME>",
    "full": "<BOT_NAME> Bot"
  },
  "description": {
    "short": "AI-powered assistant",
    "full": "An AI-powered assistant bot."
  },
  "icons": {
    "outline": "outline.png",
    "color": "color.png"
  },
  "accentColor": "#5558AF",
  "bots": [
    {
      "botId": "<APP_ID>",
      "scopes": ["personal", "team", "groupChat"],
      "supportsFiles": false,
      "isNotificationOnly": false
    }
  ],
  "permissions": ["identity", "messageTeamMembers"],
  "validDomains": ["<ENDPOINT_DOMAIN>"]
}
```

#### c. Create placeholder icons

Use Python to create simple placeholder icons:
```python
from PIL import Image
Image.new('RGBA', (192, 192), (85, 88, 175, 255)).save('teams-app/color.png')
Image.new('RGBA', (32, 32), (0, 0, 0, 0)).save('teams-app/outline.png')
```

Or inform the user they need to provide their own icons:
- `color.png`: 192x192 pixels
- `outline.png`: 32x32 pixels (transparent background)

#### d. Create the zip package

```bash
cd teams-app && zip -r ../<bot-name>.zip manifest.json color.png outline.png
```

### 6. Provide Sideloading Instructions

Tell the user:
1. Open Microsoft Teams
2. Go to **Apps** (left sidebar)
3. Click **Manage your apps** (bottom left)
4. Click **Upload an app** → **Upload a custom app**
5. Select the generated `.zip` file

## Utility Scripts

### Update Messaging Endpoint
When the user's tunnel URL changes:
```bash
az bot update --resource-group "<resource-group>" --name "<bot-name>" --endpoint "<new-endpoint>"
```

Or use the helper script:
```powershell
.\Update-TeamsBotEndpoint.ps1 -BotName "<bot-name>" -ResourceGroupName "<resource-group>" -MessagingEndpoint "<new-endpoint>"
```

### Regenerate Secret
```powershell
.\New-TeamsBotSecret.ps1 -BotName "<bot-name>" -ResourceGroupName "<resource-group>"
```

### Delete Bot
```powershell
.\Remove-TeamsBot.ps1 -BotName "<bot-name>" -ResourceGroupName "<resource-group>"
```

## Notes

- The bot is created as **SingleTenant** (MultiTenant is deprecated by Azure)
- Microsoft Graph `User.Read.All` permission is added for OpenClaw.ai integration
- Admin consent is automatically granted if the user has sufficient permissions
- Credentials are only displayed once during creation - remind users to save them securely
