param location string = resourceGroup().location
param accountPrefixes array = ['logs', 'data', 'media']
param containerNames array = ['images', 'videos', 'docs']

resource accounts 'Microsoft.Storage/storageAccounts@2023-05-01' = [
  for prefix in accountPrefixes: {
    name: 'st${prefix}${uniqueString(resourceGroup().id)}'
    location: location
    sku: { name: 'Standard_LRS' }
    kind: 'StorageV2'
    properties: {
      minimumTlsVersion: 'TLS1_2'
      allowBlobPublicAccess: false
    }
  }
]

// The containers all go in the last account ('media').
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: accounts[2]
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for name in containerNames: {
    parent: blobService
    name: name
  }
]

output accountNames array = [for (prefix, i) in accountPrefixes: accounts[i].name]
