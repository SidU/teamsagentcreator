#!/bin/bash
#
# Register a new bot in Microsoft Azure and enable it for Microsoft Teams
#
# This script creates:
# - An Azure AD App Registration (bot identity)
# - An Azure Bot Service resource (SingleTenant)
# - Enables the Microsoft Teams channel
# - Adds Microsoft Graph User.Read.All permission (for OpenClaw.ai integration)
# - Grants admin consent for the permissions
#
# Usage:
#   ./register-teams-bot.sh <bot-name> <resource-group> <messaging-endpoint>
#
# Example:
#   ./register-teams-bot.sh my-bot my-bot-rg https://mybot.example.com/api/messages
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <bot-name> <resource-group> <messaging-endpoint>"
    echo ""
    echo "Example:"
    echo "  $0 my-bot my-bot-rg https://mybot.example.com/api/messages"
    exit 1
fi

BOT_NAME="$1"
RESOURCE_GROUP="$2"
MESSAGING_ENDPOINT="$3"
LOCATION="${4:-westus}"

# Validate endpoint is HTTPS
if [[ ! "$MESSAGING_ENDPOINT" =~ ^https:// ]]; then
    error "Messaging endpoint must start with https://"
fi

# Check if logged in
info "Checking Azure login status..."
if ! az account show &>/dev/null; then
    warning "Not logged into Azure. Initiating login..."
    az login
fi

# Get account info
ACCOUNT_INFO=$(az account show --output json)
TENANT_ID=$(echo "$ACCOUNT_INFO" | jq -r '.tenantId')
SUBSCRIPTION_ID=$(echo "$ACCOUNT_INFO" | jq -r '.id')
SUBSCRIPTION_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.name')
USER_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.user.name')

success "Logged in as: $USER_NAME"
info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create or verify resource group
info "Checking resource group: $RESOURCE_GROUP"
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    info "Creating resource group: $RESOURCE_GROUP in $LOCATION"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    success "Resource group created"
else
    success "Resource group already exists"
fi

# Check if app already exists
info "Checking if app registration already exists..."
EXISTING_APP=$(az ad app list --display-name "$BOT_NAME" --query "[0].appId" --output tsv 2>/dev/null || echo "")
if [ -n "$EXISTING_APP" ]; then
    error "App registration '$BOT_NAME' already exists with App ID: $EXISTING_APP. Use a different name or delete the existing one."
fi

# Create Azure AD App Registration
info "Creating Azure AD App Registration: $BOT_NAME"
APP_INFO=$(az ad app create --display-name "$BOT_NAME" --output json)
APP_ID=$(echo "$APP_INFO" | jq -r '.appId')
APP_OBJECT_ID=$(echo "$APP_INFO" | jq -r '.id')
success "App Registration created with ID: $APP_ID"

# Create client secret (valid for 2 years)
info "Creating client secret..."
SECRET_INFO=$(az ad app credential reset --id "$APP_ID" --append --years 2 --output json)
APP_SECRET=$(echo "$SECRET_INFO" | jq -r '.password')
success "Client secret created"

# Small delay to ensure propagation
sleep 2

# Add Microsoft Graph User.Read.All permission
info "Adding Microsoft Graph User.Read.All permission..."

# Microsoft Graph API App ID and User.Read.All permission ID (these are constants)
GRAPH_API_ID="00000003-0000-0000-c000-000000000000"
USER_READ_ALL_ID="df021288-bdef-4463-88db-98f22de89214"

az ad app permission add \
    --id "$APP_ID" \
    --api "$GRAPH_API_ID" \
    --api-permissions "${USER_READ_ALL_ID}=Role" \
    --output none 2>/dev/null || warning "Permission may already exist"

success "Microsoft Graph User.Read.All permission added"

# Create service principal if it doesn't exist
info "Creating service principal..."
az ad sp create --id "$APP_ID" --output none 2>/dev/null || true
sleep 2

# Grant admin consent
info "Granting admin consent for Microsoft Graph permissions..."
if az ad app permission admin-consent --id "$APP_ID" 2>/dev/null; then
    success "Admin consent granted"
else
    warning "Could not auto-grant admin consent. Please grant manually in Azure Portal:"
    warning "  Azure Portal > App registrations > $BOT_NAME > API permissions > Grant admin consent"
fi

# Create the Azure Bot resource
info "Creating Azure Bot Service: $BOT_NAME"

if az bot create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BOT_NAME" \
    --appid "$APP_ID" \
    --app-type "SingleTenant" \
    --tenant-id "$TENANT_ID" \
    --endpoint "$MESSAGING_ENDPOINT" \
    --output none 2>&1; then
    success "Azure Bot Service created"
else
    error "Failed to create bot service"
fi

# Enable Microsoft Teams channel
info "Enabling Microsoft Teams channel..."
if az bot msteams create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BOT_NAME" \
    --output none 2>&1; then
    success "Microsoft Teams channel enabled"
else
    warning "Failed to enable Teams channel. You may need to enable it manually in Azure Portal."
fi

# Output results
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BOT REGISTRATION COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Bot Name:           ${NC}$BOT_NAME"
echo -e "Resource Group:     ${NC}$RESOURCE_GROUP"
echo -e "Messaging Endpoint: ${NC}$MESSAGING_ENDPOINT"
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  CREDENTIALS (SAVE THESE SECURELY!)${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "App ID (MicrosoftAppId):           ${CYAN}$APP_ID${NC}"
echo -e "App Secret (MicrosoftAppPassword): ${CYAN}$APP_SECRET${NC}"
echo -e "Tenant ID (MicrosoftAppTenantId):  ${CYAN}$TENANT_ID${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo ""
info "Add these to your bot's configuration (appsettings.json, .env, etc.)"
echo ""

# Output JSON for programmatic use
cat << EOF > "${BOT_NAME}-credentials.json"
{
  "botName": "$BOT_NAME",
  "resourceGroup": "$RESOURCE_GROUP",
  "endpoint": "$MESSAGING_ENDPOINT",
  "appId": "$APP_ID",
  "appSecret": "$APP_SECRET",
  "tenantId": "$TENANT_ID",
  "subscriptionId": "$SUBSCRIPTION_ID"
}
EOF

info "Credentials also saved to: ${BOT_NAME}-credentials.json"
