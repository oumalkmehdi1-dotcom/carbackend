// ============================================================
// infra/main.bicep — Azure Infrastructure for Car Rental App
// ============================================================
// Deploys: Resource Group resources
//   - Azure SQL Server + Database (Basic tier)
//   - Azure Storage Account + Blob Container
//   - Azure App Service Plan (B1 Linux) + Web App
//
// Usage:
//   az deployment group create \
//     --resource-group car-rental-rg \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters.json
// ============================================================

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Unique suffix for resource names (use 4-6 random chars)')
param uniqueSuffix string

@description('SQL Server admin username')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server admin password')
@secure()
param sqlAdminPassword string

// ============================================================
// Names (must be globally unique)
// ============================================================
var sqlServerName = 'carrental-sql-${uniqueSuffix}'
var sqlDatabaseName = 'carrentaldb'
var storageAccountName = 'carrental${uniqueSuffix}'
var appServicePlanName = 'carrental-plan-${uniqueSuffix}'
var webAppName = 'carrental-app-${uniqueSuffix}'
var blobContainerName = 'car-images'

// ============================================================
// 1. Azure SQL Server
// ============================================================
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled' // Required for App Service connection
  }
}

// Allow Azure services to access SQL Server
resource sqlFirewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Allow all IPs (for testing only — restrict in production)
resource sqlFirewallAllowAll 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllForTesting'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// ============================================================
// 2. Azure SQL Database (Basic tier — cheapest)
// ============================================================
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'       // ~$5/month
    tier: 'Basic'
    capacity: 5         // 5 DTUs
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
  }
}

// ============================================================
// 3. Azure Storage Account (Standard LRS — cheapest)
// ============================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS' // Locally redundant — cheapest
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true  // Needed for public car images
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// Container for car images (public read access for blobs)
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: blobContainerName
  properties: {
    publicAccess: 'Blob' // Public read access for individual blobs
  }
}

// ============================================================
// 4. App Service Plan (B1 Linux — cheapest paid tier)
// ============================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'         // Basic tier ~$13/month
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true     // Required for Linux
  }
}

// ============================================================
// 5. Web App (Node.js 20 on Linux)
// ============================================================
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appCommandLine: 'node server.js'
      alwaysOn: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'PORT'
          value: '8080'
        }
        {
          name: 'DB_SERVER'
          value: '${sqlServer.name}.database.windows.net'
        }
        {
          name: 'DB_NAME'
          value: sqlDatabaseName
        }
        {
          name: 'DB_USER'
          value: sqlAdminLogin
        }
        {
          name: 'DB_PASSWORD'
          value: sqlAdminPassword
        }
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'AZURE_STORAGE_CONTAINER'
          value: blobContainerName
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
      ]
    }
  }
}

// ============================================================
// Outputs — needed for deployment and .env configuration
// ============================================================
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppName string = webApp.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabaseName
output storageAccountName string = storageAccount.name
output blobContainerName string = blobContainerName
