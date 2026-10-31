param location string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stsub${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output storageName string = storage.name
