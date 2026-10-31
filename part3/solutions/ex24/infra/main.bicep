param location string = resourceGroup().location

@allowed(['Standard_LRS', 'Standard_ZRS'])
param storageSku string = 'Standard_LRS'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stcicd${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: storageSku }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output storageName string = storage.name
