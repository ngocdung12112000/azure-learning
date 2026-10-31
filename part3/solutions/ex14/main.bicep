@description('Short name prefix. uniqueString() adds 13 characters, and the limit is 24.')
@minLength(3)
@maxLength(11)
param prefix string = 'stlab'

@description('Storage redundancy')
@allowed(['Standard_LRS', 'Standard_ZRS'])
param storageSku string = 'Standard_LRS'

param location string = resourceGroup().location

// Both params are unused on purpose. Compare how deployment history shows them.
param plainNote string = 'anyone can read this'

@secure()
param secretNote string = ''

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${toLower(prefix)}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: storageSku }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output blobEndpoint string = storage.properties.primaryEndpoints.blob
