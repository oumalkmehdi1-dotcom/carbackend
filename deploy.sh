#!/bin/bash
# ============================================================
# deploy.sh — One-Command Azure Deployment Script
# ============================================================
# This script creates all Azure resources and deploys your app.
#
# Prerequisites:
#   1. Azure CLI installed: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
#   2. Logged in: az login
#   3. Active subscription
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# ============================================================

set -e  # Exit on any error

# ============================================================
# CONFIGURATION — Change these values!
# ============================================================
RESOURCE_GROUP="car-rental-rg"
LOCATION="eastus"                          # Cheapest region
UNIQUE_SUFFIX="cr$(date +%s | tail -c 7)" # Random 6-char suffix
SQL_ADMIN_LOGIN="sqladmin"
SQL_ADMIN_PASSWORD="CarRental2026!"        # Change this!

# Derived names
SQL_SERVER="carrental-sql-${UNIQUE_SUFFIX}"
SQL_DATABASE="carrentaldb"
STORAGE_ACCOUNT="carrental${UNIQUE_SUFFIX}"
BLOB_CONTAINER="car-images"
APP_PLAN="carrental-plan-${UNIQUE_SUFFIX}"
WEB_APP="carrental-app-${UNIQUE_SUFFIX}"

echo "============================================"
echo "  Car Rental App — Azure Deployment"
echo "============================================"
echo ""
echo "Resources will be created with suffix: ${UNIQUE_SUFFIX}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location: ${LOCATION}"
echo ""

# ============================================================
# Step 1: Create Resource Group
# ============================================================
echo "📦 Step 1/7: Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
echo "   ✅ Resource Group created."

# ============================================================
# Step 2: Create Azure SQL Server
# ============================================================
echo "🗄️  Step 2/7: Creating SQL Server..."
az sql server create \
  --name "$SQL_SERVER" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_LOGIN" \
  --admin-password "$SQL_ADMIN_PASSWORD" \
  --output none
echo "   ✅ SQL Server created: ${SQL_SERVER}.database.windows.net"

# Allow Azure services to connect
echo "   🔓 Configuring firewall rules..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER" \
  --name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  --output none

# Allow all IPs for testing (restrict in production!)
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER" \
  --name "AllowAllForTesting" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255 \
  --output none
echo "   ✅ Firewall rules configured."

# ============================================================
# Step 3: Create SQL Database (Basic tier — cheapest)
# ============================================================
echo "📊 Step 3/7: Creating SQL Database..."
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER" \
  --name "$SQL_DATABASE" \
  --edition Basic \
  --capacity 5 \
  --max-size 2GB \
  --output none
echo "   ✅ Database created: ${SQL_DATABASE}"

# ============================================================
# Step 4: Create Storage Account
# ============================================================
echo "📁 Step 4/7: Creating Storage Account..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access true \
  --min-tls-version TLS1_2 \
  --output none
echo "   ✅ Storage Account created: ${STORAGE_ACCOUNT}"

# Get storage connection string
STORAGE_CONN_STRING=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query connectionString -o tsv)

# Create blob container with public read access
echo "   📦 Creating blob container..."
az storage container create \
  --name "$BLOB_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --public-access blob \
  --output none
echo "   ✅ Blob container created: ${BLOB_CONTAINER}"

# ============================================================
# Step 5: Create App Service Plan (B1 Linux — cheapest paid)
# ============================================================
echo "📋 Step 5/7: Creating App Service Plan..."
az appservice plan create \
  --name "$APP_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku B1 \
  --is-linux \
  --output none
echo "   ✅ App Service Plan created (B1 Linux)."

# ============================================================
# Step 6: Create Web App + Configure Environment
# ============================================================
echo "🌐 Step 6/7: Creating Web App..."
az webapp create \
  --name "$WEB_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_PLAN" \
  --runtime "NODE:18-lts" \
  --output none

# Set app settings (environment variables)
echo "   ⚙️  Configuring app settings..."
az webapp config appsettings set \
  --name "$WEB_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    PORT=8080 \
    DB_SERVER="${SQL_SERVER}.database.windows.net" \
    DB_NAME="${SQL_DATABASE}" \
    DB_USER="${SQL_ADMIN_LOGIN}" \
    DB_PASSWORD="${SQL_ADMIN_PASSWORD}" \
    AZURE_STORAGE_CONNECTION_STRING="${STORAGE_CONN_STRING}" \
    AZURE_STORAGE_CONTAINER="${BLOB_CONTAINER}" \
  --output none

# Set startup command
az webapp config set \
  --name "$WEB_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --startup-file "node server.js" \
  --output none
echo "   ✅ Web App created and configured."

# ============================================================
# Step 7: Deploy Code
# ============================================================
echo "🚀 Step 7/7: Deploying code..."
cd "$(dirname "$0")"

# Zip the project (exclude unnecessary files)
rm -f deploy.zip
zip -r deploy.zip . \
  -x "node_modules/*" \
  -x ".env" \
  -x "carrental.db" \
  -x "deploy.zip" \
  -x ".git/*" \
  -x "infra/*" \
  -x "deploy.sh" \
  -x "deploy.ps1"

az webapp deploy \
  --name "$WEB_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --src-path deploy.zip \
  --type zip \
  --output none

rm -f deploy.zip
echo "   ✅ Code deployed!"

# ============================================================
# Step 8: Setup Database Tables
# ============================================================
echo ""
echo "⏳ Waiting 30 seconds for app to start..."
sleep 30

# The app creates tables on first request, but let's set up via the setup script
echo "🔧 Run the database setup script locally:"
echo "   Update your .env file with these values, then run: npm run setup-db"

# ============================================================
# Done!
# ============================================================
APP_URL="https://${WEB_APP}.azurewebsites.net"
echo ""
echo "============================================"
echo "  🎉 DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "  🌐 App URL:    ${APP_URL}"
echo "  📋 Admin URL:  ${APP_URL}/admin.html"
echo ""
echo "  📊 SQL Server: ${SQL_SERVER}.database.windows.net"
echo "  📁 Storage:    ${STORAGE_ACCOUNT}"
echo "  💻 Web App:    ${WEB_APP}"
echo ""
echo "  ⚠️  NEXT STEP: Initialize the database tables!"
echo "     1. Update your local .env file with the values above"
echo "     2. Run: npm run setup-db"
echo ""
echo "  🧹 To delete everything when done:"
echo "     az group delete --name ${RESOURCE_GROUP} --yes"
echo ""
