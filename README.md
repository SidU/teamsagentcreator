# Teams Bot Creator for OpenClaw

Easily register Microsoft Teams bots in Azure using AI coding agents. Built for seamless integration with [OpenClaw.ai](https://openclaw.ai).

## What This Does

This repo contains scripts and agent instructions that let you:

- **Register a new Teams bot** in Azure with a single command
- **Configure Microsoft Graph permissions** (User.Read.All) automatically
- **Generate a Teams app package** ready for sideloading
- **Update your bot's callback URL** when your tunnel changes
- **Rotate credentials** when needed

## Quick Start

### Using an AI Coding Agent (Recommended)

Simply open this repo in your favorite AI coding agent (Claude Code, Cursor, etc.) and ask:

> "Register a new Teams bot for OpenClaw"

The agent will:
1. Ask you for the bot name, resource group, and messaging endpoint
2. Run the registration script
3. Create a Teams app package you can sideload
4. Provide you with the credentials to configure in OpenClaw

### Manual Usage

**Prerequisites:**
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- Azure subscription with permissions to create Bot Services and App Registrations

**Register a bot:**
```bash
# Login to Azure
az login

# Run the registration script
./register-teams-bot.sh my-bot my-bot-rg https://your-endpoint.example.com/api/messages
```

**Update the callback URL:**
```bash
az bot update --resource-group "my-bot-rg" --name "my-bot" --endpoint "https://new-endpoint.example.com/api/messages"
```

## What Gets Created

When you register a bot, the script creates:

| Resource | Description |
|----------|-------------|
| Azure AD App Registration | Bot identity with client secret |
| Azure Bot Service | SingleTenant bot resource |
| Microsoft Teams Channel | Enables the bot for Teams |
| Graph API Permission | User.Read.All with admin consent |

## Files

| File | Description |
|------|-------------|
| `register-teams-bot.sh` | Main registration script (Bash/Azure CLI) |
| `Register-TeamsBot.ps1` | Registration script (PowerShell) |
| `Update-TeamsBotEndpoint.ps1` | Update bot's messaging endpoint |
| `New-TeamsBotSecret.ps1` | Generate new client secret |
| `Remove-TeamsBot.ps1` | Delete bot and app registration |
| `AGENTS.md` | Instructions for AI coding agents |

## Using with OpenClaw

After registration, configure your OpenClaw bot with:

- **App ID** (MicrosoftAppId)
- **App Secret** (MicrosoftAppPassword)
- **Tenant ID** (MicrosoftAppTenantId)

Then sideload the generated Teams app package to start chatting with your bot.

## License

MIT
