@allowed(['dev', 'prod'])
param env string

@allowed(['B1', 'S1', 'P1v3'])
param appServiceSku string

@minValue(1)
param instanceCount int

param zoneRedundant bool

@allowed(['Standard_LRS', 'Standard_ZRS'])
param storageSku string

param location string = resourceGroup().location

var suffix = uniqueString(resourceGroup().id)

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-${env}-${suffix}'
  location: location
  kind: 'linux'
  sku: {
    name: appServiceSku
    capacity: instanceCount
  }
  properties: {
    reserved: true
    zoneRedundant: zoneRedundant
  }
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: 'app-${env}-${suffix}'
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      minTlsVersion: '1.2'
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${env}${suffix}'
  location: location
  sku: { name: storageSku }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
