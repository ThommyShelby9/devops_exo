targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param resourceGroupName string = ''
param webServiceName string = ''
param catalogDatabaseName string = 'catalogDatabase'
param catalogDatabaseServerName string = ''
param identityDatabaseName string = 'identityDatabase'
param identityDatabaseServerName string = ''
param appServicePlanName string = ''
param keyVaultName string = ''
param logAnalyticsName string = ''
param applicationInsightsName string = ''
param containerRegistryName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

@secure()
@description('Application user password')
param appUserPassword string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'Compliance': 'HDS'
  'RGPD': 'Article9'
  'ISO': '27001'
  'Project': 'MedSecure'
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Monitoring and Observability (HDS compliance)
module logAnalytics './core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    retentionInDays: 90 // HDS minimum requirement
  }
}

module applicationInsights './core/monitor/applicationinsights.bicep' = {
  name: 'applicationinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    samplingPercentage: 100 // HDS: 100% sampling for full audit trail
  }
}

// The application frontend
module web './core/host/appservice.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    applicationInsightsName: applicationInsights.outputs.name
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    healthCheckPath: '/health'
    tags: union(tags, { 'azd-service-name': 'web' })
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
    }
  }
}

module apiKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: web.outputs.identityPrincipalId
  }
}

// The application database: Catalog
module catalogDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-catalog'
  scope: rg
  params: {
    name: !empty(catalogDatabaseServerName) ? catalogDatabaseServerName : '${abbrs.sqlServers}catalog-${resourceToken}'
    databaseName: catalogDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// The application database: Identity
module identityDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-identity'
  scope: rg
  params: {
    name: !empty(identityDatabaseServerName) ? identityDatabaseServerName : '${abbrs.sqlServers}identity-${resourceToken}'
    databaseName: identityDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Azure Container Registry for Docker images (HDS compliance)
module containerRegistry './core/container/registry.bicep' = {
  name: 'containerregistry'
  scope: rg
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    sku: 'Premium'
    adminUserEnabled: false
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Grant App Service access to pull images from ACR
module acrPullRoleAssignment './core/security/role-assignment.bicep' = {
  name: 'acr-pull-role'
  scope: rg
  params: {
    principalId: web.outputs.identityPrincipalId
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role
    principalType: 'ServicePrincipal'
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
// S1 (Standard) required for HDS: deployment slots, auto-scaling, 99.95% SLA
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'S1'
      tier: 'Standard'
      capacity: 1
    }
    maximumElasticWorkerCount: 3
  }
}

// Data outputs
output AZURE_SQL_CATALOG_CONNECTION_STRING_KEY string = catalogDb.outputs.connectionStringKey
output AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY string = identityDb.outputs.connectionStringKey
output AZURE_SQL_CATALOG_DATABASE_NAME string = catalogDb.outputs.databaseName
output AZURE_SQL_IDENTITY_DATABASE_NAME string = identityDb.outputs.databaseName

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

// Monitoring outputs
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.id
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.outputs.name
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output APPLICATIONINSIGHTS_NAME string = applicationInsights.outputs.name

// Container Registry outputs
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_LOGIN_SERVER string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = 'https://${containerRegistry.outputs.loginServer}'
