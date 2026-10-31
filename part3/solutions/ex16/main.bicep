@allowed(['dev', 'prod'])
param env string = 'dev'

param location string = resourceGroup().location

var suffix = uniqueString(resourceGroup().id)
var isProd = env == 'prod'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${env}${suffix}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// Application Insights stores its data in a Log Analytics workspace.
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (isProd) {
  name: 'log-${suffix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (isProd) {
  name: 'appi-${suffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace!.id
  }
}

output storageName string = storage.name
output appInsightsDeployed bool = isProd
