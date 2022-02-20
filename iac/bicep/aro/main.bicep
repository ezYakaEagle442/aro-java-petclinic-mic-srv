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
  }
  dependsOn: [
    vnet
  ]  
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
