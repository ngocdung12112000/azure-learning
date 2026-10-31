param location string = resourceGroup().location
param sshPublicKey string
param adminUsername string = 'azureuser'

module nsg 'br/public:avm/res/network/network-security-group:0.5.4' = {
  name: 'nsg'
  params: {
    name: 'nsg-avm'
    location: location
    securityRules: [
      {
        name: 'allow-http'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

module vnet 'br/public:avm/res/network/virtual-network:0.10.2' = {
  name: 'vnet'
  params: {
    name: 'vnet-avm'
    location: location
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: 'snet-web'
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
      {
        name: 'snet-data'
        addressPrefix: '10.0.2.0/24'
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
    ]
  }
}

module vm 'br/public:avm/res/compute/virtual-machine:0.22.3' = {
  name: 'vm'
  params: {
    name: 'vm-avm-1'
    location: location
    availabilityZone: 1
    osType: 'Linux'
    vmSize: 'Standard_B1s'
    adminUsername: adminUsername
    disablePasswordAuthentication: true
    publicKeys: [
      {
        keyData: sshPublicKey
        path: '/home/${adminUsername}/.ssh/authorized_keys'
      }
    ]
    imageReference: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 32
      managedDisk: { storageAccountType: 'StandardSSD_LRS' }
    }
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
          }
        ]
      }
    ]
  }
}
