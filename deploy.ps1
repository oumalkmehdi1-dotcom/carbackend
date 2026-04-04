# ============================================================
# deploy.ps1 — One-Command Azure Deployment Script (Windows)
# ============================================================
# This script creates all Azure resources and deploys your app.
#
# Prerequisites:
#   1. Azure CLI installed: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
#   2. Logged in: az login
#   3. Active subscription
#
# Usage:
#   .\deploy.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION — Change these values!
# ============================================================
$RESOURCE_GROUP = "car-rental-rg"
$LOCATION = "eastus"
$UNIQUE_SUFFIX = "cr" + (Get-Date -Format "HHmmss")
$SQL_ADMIN_LOGIN = "sqladmin"
$SQL_ADMIN_PASSWORD = "CarRental2026!"    # Change this!

# Derived names
$SQL_SERVER = "carrental-sql-$UNIQUE_SUFFIX"
$SQL_DATABASE = "carrentaldb"
$STORAGE_ACCOUNT = "carrental$UNIQUE_SUFFIX"
$BLOB_CONTAINER = "car-images"
$APP_PLAN = "carrental-plan-$UNIQUE_SUFFIX"
$WEB_APP = "carrental-app-$UNIQUE_SUFFIX"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Car Rental App - Azure Deployment" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resources will be created with suffix: $UNIQUE_SUFFIX"
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Location: $LOCATION"
Write-Host ""

# ============================================================
# Check Azure CLI
# ============================================================
try {
    $null = az --version 2>$null
} catch {
    Write-Host "ERROR: Azure CLI is not installed!" -ForegroundColor Red
    Write-Host "Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows" -ForegroundColor Yellow
    exit 1
}

# ============================================================
# Step 1: Create Resource Group
# ============================================================
Write-Host "Step 1/7: Creating Resource Group..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
Write-Host "  Resource Group created." -ForegroundColor Green

# ============================================================
# Step 2: Create Azure SQL Server
# ============================================================
Write-Host "Step 2/7: Creating SQL Server..." -ForegroundColor Yellow
az sql server create `
    --name $SQL_SERVER `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --admin-user $SQL_ADMIN_LOGIN `
    --admin-password $SQL_ADMIN_PASSWORD `
    --output none
Write-Host "  SQL Server created: $SQL_SERVER.database.windows.net" -ForegroundColor Green

Write-Host "  Configuring firewall rules..."
az sql server firewall-rule create `
    --resource-group $RESOURCE_GROUP `
    --server $SQL_SERVER `
    --name "AllowAzureServices" `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0 `
    --output none

az sql server firewall-rule create `
    --resource-group $RESOURCE_GROUP `
    --server $SQL_SERVER `
    --name "AllowAllForTesting" `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 255.255.255.255 `
    --output none
Write-Host "  Firewall rules configured." -ForegroundColor Green

# ============================================================
# Step 3: Create SQL Database (Basic tier — cheapest)
# ============================================================
Write-Host "Step 3/7: Creating SQL Database..." -ForegroundColor Yellow
az sql db create `
    --resource-group $RESOURCE_GROUP `
    --server $SQL_SERVER `
    --name $SQL_DATABASE `
    --edition Basic `
    --capacity 5 `
    --max-size 2GB `
    --output none
Write-Host "  Database created: $SQL_DATABASE" -ForegroundColor Green

# ============================================================
# Step 4: Create Storage Account
# ============================================================
Write-Host "Step 4/7: Creating Storage Account..." -ForegroundColor Yellow
az storage account create `
    --name $STORAGE_ACCOUNT `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --sku Standard_LRS `
    --kind StorageV2 `
    --allow-blob-public-access true `
    --min-tls-version TLS1_2 `
    --output none
Write-Host "  Storage Account created: $STORAGE_ACCOUNT" -ForegroundColor Green

# Get storage connection string
$STORAGE_CONN_STRING = az storage account show-connection-string `
    --name $STORAGE_ACCOUNT `
    --resource-group $RESOURCE_GROUP `
    --query connectionString -o tsv

# Create blob container
Write-Host "  Creating blob container..."
az storage container create `
    --name $BLOB_CONTAINER `
    --account-name $STORAGE_ACCOUNT `
    --public-access blob `
    --output none
Write-Host "  Blob container created: $BLOB_CONTAINER" -ForegroundColor Green

# ============================================================
# Step 5: Create App Service Plan (B1 Linux — cheapest paid)
# ============================================================
Write-Host "Step 5/7: Creating App Service Plan..." -ForegroundColor Yellow
az appservice plan create `
    --name $APP_PLAN `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --sku B1 `
    --is-linux `
    --output none
Write-Host "  App Service Plan created (B1 Linux)." -ForegroundColor Green

# ============================================================
# Step 6: Create Web App + Configure Environment
# ============================================================
Write-Host "Step 6/7: Creating Web App..." -ForegroundColor Yellow
az webapp create `
    --name $WEB_APP `
    --resource-group $RESOURCE_GROUP `
    --plan $APP_PLAN `
    --runtime "NODE:18-lts" `
    --output none

Write-Host "  Configuring app settings..."
az webapp config appsettings set `
    --name $WEB_APP `
    --resource-group $RESOURCE_GROUP `
    --settings `
    PORT=8080 `
    DB_SERVER="$SQL_SERVER.database.windows.net" `
    DB_NAME=$SQL_DATABASE `
    DB_USER=$SQL_ADMIN_LOGIN `
    DB_PASSWORD=$SQL_ADMIN_PASSWORD `
    AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONN_STRING `
    AZURE_STORAGE_CONTAINER=$BLOB_CONTAINER `
    --output none

az webapp config set `
    --name $WEB_APP `
    --resource-group $RESOURCE_GROUP `
    --startup-file "node server.js" `
    --output none
Write-Host "  Web App created and configured." -ForegroundColor Green

# ============================================================
# Step 7: Deploy Code
# ============================================================
Write-Host "Step 7/7: Deploying code..." -ForegroundColor Yellow

Push-Location $PSScriptRoot

# Create zip excluding unnecessary files
$tempZip = Join-Path $PSScriptRoot "deploy.zip"
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

# Get all files except excluded ones
$excludeDirs = @("node_modules", ".git", "infra")
$excludeFiles = @(".env", "carrental.db", "deploy.zip", "deploy.sh", "deploy.ps1")

$filesToZip = Get-ChildItem -Path $PSScriptRoot -Recurse -File | Where-Object {
    $path = $_.FullName
    $excluded = $false
    foreach ($dir in $excludeDirs) {
        if ($path -match [regex]::Escape((Join-Path $PSScriptRoot $dir))) {
            $excluded = $true
            break
        }
    }
    if (-not $excluded) {
        foreach ($file in $excludeFiles) {
            if ($_.Name -eq $file) {
                $excluded = $true
                break
            }
        }
    }
    -not $excluded
}

Compress-Archive -Path ($filesToZip | Select-Object -ExpandProperty FullName) -DestinationPath $tempZip -Force

az webapp deploy `
    --name $WEB_APP `
    --resource-group $RESOURCE_GROUP `
    --src-path $tempZip `
    --type zip `
    --output none

Remove-Item $tempZip -Force
Pop-Location

Write-Host "  Code deployed!" -ForegroundColor Green

# ============================================================
# Update local .env for database setup
# ============================================================
$envContent = @"
PORT=8080
DB_SERVER=$SQL_SERVER.database.windows.net
DB_NAME=$SQL_DATABASE
DB_USER=$SQL_ADMIN_LOGIN
DB_PASSWORD=$SQL_ADMIN_PASSWORD
AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONN_STRING
AZURE_STORAGE_CONTAINER=$BLOB_CONTAINER
"@

$envPath = Join-Path $PSScriptRoot ".env"
$envContent | Set-Content -Path $envPath -Encoding UTF8
Write-Host ""
Write-Host "  .env file updated with Azure credentials." -ForegroundColor Green

# ============================================================
# Setup Database Tables
# ============================================================
Write-Host ""
Write-Host "Setting up database tables..." -ForegroundColor Yellow
Push-Location $PSScriptRoot
npm run setup-db
Pop-Location
Write-Host "  Database tables created!" -ForegroundColor Green

# ============================================================
# Done!
# ============================================================
$APP_URL = "https://$WEB_APP.azurewebsites.net"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  App URL:    $APP_URL" -ForegroundColor Cyan
Write-Host "  Admin URL:  $APP_URL/admin.html" -ForegroundColor Cyan
Write-Host ""
Write-Host "  SQL Server: $SQL_SERVER.database.windows.net"
Write-Host "  Storage:    $STORAGE_ACCOUNT"
Write-Host "  Web App:    $WEB_APP"
Write-Host ""
Write-Host "  To delete everything when done:" -ForegroundColor Yellow
Write-Host "  az group delete --name $RESOURCE_GROUP --yes" -ForegroundColor Yellow
Write-Host ""

# Open the app in the browser
Start-Process $APP_URL
