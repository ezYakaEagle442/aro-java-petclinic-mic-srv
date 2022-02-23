@description('A UNIQUE name')
@maxLength(20)
param appName string = 'iacdemo${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location

param clientId string
param clientObjectId string
param aroRpObjectId string

@secure()
param clientSecret string

param domain string
param pullSecret string
param clusterName string = 'aro-java-petclinic'

param vnetName string = 'vnet-aro'
param vnetCidr string = '172.32.0.0/21'
param masterSubnetCidr string = '172.32.1.0/24'
param workerSubnetCidr string = '172.32.2.0/24'

@maxLength(24)
@description('The name of the KV, must be UNIQUE.  A vault name must be between 3-24 alphanumeric characters.')
param kvName string // = 'kv-${appName}'

@description('The name of the KV RG')
param kvRGName string

@description('Is KV Network access public ?')
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string = 'enabled'

@description('The KV SKU name')
@allowed([
  'premium'
  'standard'
])
param skuName string = 'standard'

@description('The Azure Active Directory tenant ID that should be used for authenticating requests to the Key Vault.')
param tenantId string = subscription().tenantId

@description('The MySQL DB Admin Login.')
param administratorLogin string = 'mys_adm'

@secure()
@description('The MySQL DB Admin Password.')
param administratorLoginPassword string


module vnet 'vnet.bicep' = {
  name: 'vnet-aro'
  params: {
    vnetName: vnetName
    masterSubnetCidr: masterSubnetCidr
    vnetCidr: vnetCidr
    workerSubnetCidr: workerSubnetCidr
  }
}

module vnetRoleAssignments 'roleAssignments.bicep' = {
  name: 'role-assignments'
  params: {
    vnetId: vnet.outputs.vnetId
    clientObjectId: clientObjectId
    aroRpObjectId: aroRpObjectId
    kvName: kvName
    kvRGName: kvRGName
    kvRoleType: 'KeyVaultReader'    
  }
}

module aro 'aro.bicep' = {
  name: 'aro'
  params: {
    domain: domain
    masterSubnetId: vnet.outputs.masterSubnetId
    workerSubnetId: vnet.outputs.workerSubnetId
    clientId: clientId
    clientSecret: clientSecret
    pullSecret: pullSecret
    clusterName: clusterName
  }

  dependsOn: [
    vnetRoleAssignments
  ]
}

module mysql '../mysql/mysql.bicep' = {
  name: 'mysqldb'
  params: {
    appName: appName
    location: location
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}


var vNetRules = [
  {
    'id': vnet.outputs.workerSubnetId
    'ignoreMissingVnetServiceEndpoint': false
  }
]

// At this stage, must be configured: networkAcls/virtualNetworkRules to allow to ARO subnetID
module KeyVault '../kv/kv.bicep'= {
  name: kvName
  scope: resourceGroup(kvRGName)
  params: {
    location: location
    skuName: skuName
    tenantId: tenantId
    publicNetworkAccess: publicNetworkAccess
    vNetRules: vNetRules
    clientObjectId: clientObjectId
    setKVAccessPolicies: true
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  scope: resourceGroup(kvRGName)
  name: kvName
}
