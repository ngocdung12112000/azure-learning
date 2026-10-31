param location string = resourceGroup().location

resource keep 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stkeep${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource drop 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stdrop${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}
