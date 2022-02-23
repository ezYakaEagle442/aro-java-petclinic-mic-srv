param vnetId string
param clientObjectId string
param aroRpObjectId string

@allowed([
  'KeyVaultAdministrator'
  'KeyVaultReader'
  'KeyVaultSecretsUser'  
])
@description('KV Built-in role to assign')
param kvRoleType string

param kvName string

@description('The name of the KV RG')
param kvRGName string

var roleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // contributor

resource clusterRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(vnetId, roleDefinitionId, clientObjectId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: clientObjectId
    principalType: 'ServicePrincipal'
  }
}

resource aroRpRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(vnetId, roleDefinitionId, aroRpObjectId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: aroRpObjectId
    principalType: 'ServicePrincipal'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var role = {
  Owner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  NetworkContributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
  AcrPull: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
  KeyVaultAdministrator: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483'
  KeyVaultReader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/21090545-7ca7-4776-b22c-e363652d74d2'
  KeyVaultSecretsUser: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
}

// You need Key Vault Administrator permission to be able to see the Keys/Secrets/Certificates in the Azure Portal
resource KVAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, kvRoleType , subscription().subscriptionId)
  properties: {
    roleDefinitionId: role[kvRoleType]
    principalId: aroRpObjectId
    principalType: 'ServicePrincipal'
  }
}
