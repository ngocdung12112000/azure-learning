param location string = resourceGroup().location
param keyVaultName string
param sqlAdminLogin string = 'sqladminuser'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// getSecret() can only be used to fill a module's @secure() param.
module sql 'sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    adminLogin: sqlAdminLogin
    adminPassword: keyVault.getSecret('sql-admin-password')
  }
}

output sqlServerName string = sql.outputs.serverName
