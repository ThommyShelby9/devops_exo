@description('Principal ID (Managed Identity or User)')
param principalId string

@description('Role Definition ID (GUID)')
param roleDefinitionId string

@description('Principal Type')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
  'ForeignGroup'
])
param principalType string = 'ServicePrincipal'

@description('Resource ID to assign role to (defaults to resource group scope)')
param resourceId string = resourceGroup().id

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, roleDefinitionId, resourceId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

output id string = roleAssignment.id
output name string = roleAssignment.name
