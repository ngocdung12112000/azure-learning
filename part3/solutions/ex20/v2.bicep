param location string = resourceGroup().location

// The 'drop' account from v1.bicep has been removed from this file.
resource keep 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stkeep${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}
