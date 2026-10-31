param location string
param adminLogin string

@secure()
param adminPassword string

// A logical server on its own costs nothing. Only databases are billed.
resource server 'Microsoft.Sql/servers@2023-08-01' = {
  name: 'sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

output serverName string = server.name
