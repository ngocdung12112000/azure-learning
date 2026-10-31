param location string = resourceGroup().location
param sshPublicKey string

module network 'network.bicep' = {
  name: 'network'
  params: {
    location: location
    namePrefix: 'lab'
  }
}

module vm 'vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    vmName: 'vm-lab-1'
    subnetId: network.outputs.webSubnetId
    sshPublicKey: sshPublicKey
  }
}

output vmPrivateIp string = vm.outputs.privateIp
