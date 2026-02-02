# Agent Instructions: Teams Bot Registration

This folder contains scripts to register a Microsoft Teams bot in Azure and create a sideloadable app package.

## Workflow

When a user asks to create/register a Teams bot for OpenClaw.ai or similar, follow these steps:

### 1. Gather Required Information

Ask the user for:
- **Bot name**: A unique name for the bot (alphanumeric + hyphens, 3-36 chars)
- **Resource group name**: Azure resource group (will be created if it doesn't exist)
- **Messaging endpoint**: The HTTPS callback URL where the bot receives messages

#### Getting the Messaging Endpoint URL

**Important:** If the user doesn't have a messaging endpoint URL yet, instruct them to:

1. **Message their OpenClaw bot** on WhatsApp, Telegram, or whatever channel they already have configured
2. **Ask the bot** to configure the Microsoft Teams channel:
   > "I want to add Microsoft Teams as a channel"
3. **The bot will ask for their email** to allowlist them for the Teams integration
4. **OpenClaw will provide the messaging endpoint URL** (e.g., `https://something.trycloudflare.com/api/messages`)

Once they have the messaging endpoint URL, proceed with the registration.

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

### 5. Provide Credentials to OpenClaw Bot

Instruct the user to **send these credentials back to their OpenClaw bot** (on WhatsApp/Telegram/etc.) so it can complete the Microsoft Teams configuration:

> "Send the following to your OpenClaw bot:
> - App ID: `<APP_ID>`
> - App Secret: `<APP_SECRET>`
> - Tenant ID: `<TENANT_ID>`
>
> The bot will use these to configure the Microsoft Teams plugin."

The user can simply copy/paste or type these values to their bot in the existing conversation where they requested the Teams channel setup.

### 6. Create the Teams App Package

After registration, create a Teams app manifest for sideloading. **Always create the app package for the user** - don't skip this step.

#### a. Gather App Package Information

Ask the user for these optional customizations (provide sensible defaults if they skip):
- **Display name**: Short name shown in Teams (default: use bot name)
- **Description**: Short description of the bot (default: "AI-powered assistant")
- **Developer/Company name**: Who built this (default: "Developer")
- **Accent color**: Hex color for branding (default: "#5558AF")

#### b. Create a directory for the app package
```bash
mkdir -p teams-app
```

#### c. Create `manifest.json`

Use this template, replacing placeholders with values from registration and user input:
- `<APP_ID>`: The App ID from registration
- `<BOT_DISPLAY_NAME>`: User-provided or bot name
- `<DESCRIPTION>`: User-provided or default
- `<DEVELOPER_NAME>`: User-provided or default
- `<ACCENT_COLOR>`: User-provided or default
- `<ENDPOINT_DOMAIN>`: Domain from messaging endpoint (without https:// or path)

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.17/MicrosoftTeams.schema.json",
  "manifestVersion": "1.17",
  "version": "1.0.0",
  "id": "<APP_ID>",
  "developer": {
    "name": "<DEVELOPER_NAME>",
    "websiteUrl": "https://openclaw.ai",
    "privacyUrl": "https://openclaw.ai/privacy",
    "termsOfUseUrl": "https://openclaw.ai/terms"
  },
  "name": {
    "short": "<BOT_DISPLAY_NAME>",
    "full": "<BOT_DISPLAY_NAME>"
  },
  "description": {
    "short": "<DESCRIPTION>",
    "full": "<DESCRIPTION>"
  },
  "icons": {
    "outline": "outline.png",
    "color": "color.png"
  },
  "accentColor": "<ACCENT_COLOR>",
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

#### d. Create placeholder icons

Use Python to create simple placeholder icons:
```python
from PIL import Image
Image.new('RGBA', (192, 192), (85, 88, 175, 255)).save('teams-app/color.png')
Image.new('RGBA', (32, 32), (0, 0, 0, 0)).save('teams-app/outline.png')
```

Or inform the user they can replace these later with custom icons:
- `color.png`: 192x192 pixels (full color app icon)
- `outline.png`: 32x32 pixels (transparent background, single color)

#### e. Create the zip package

```bash
cd teams-app && zip -r ../<bot-name>.zip manifest.json color.png outline.png
```

#### f. Move to user-accessible location

Move the zip file somewhere easy to find (e.g., Downloads):
```bash
mv <bot-name>.zip ~/Downloads/
```

### 7. Provide Sideloading Instructions

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
