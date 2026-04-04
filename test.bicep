resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'teststore12345'
  location: 'eastus'
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}
