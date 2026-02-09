param name string
param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics Workspace retention in days (HDS requires minimum 90 days)')
@minValue(90)
@maxValue(730)
param retentionInDays int = 90

@description('SKU for Log Analytics Workspace')
@allowed([
  'PerGB2018'
  'Premium'
  'Standalone'
])
param sku string = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: union(tags, {
    'Compliance': 'HDS'
    'Purpose': 'AuditTrail'
    'DataRetention': '90days'
  })
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Diagnostic settings for Log Analytics itself
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'audit-logs'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
