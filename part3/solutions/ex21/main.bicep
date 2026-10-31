targetScope = 'subscription'

param location string
param rgName string = 'rg-bicep-sub-lab'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
}

module storage 'storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
  }
}

output storageName string = storage.outputs.storageName
