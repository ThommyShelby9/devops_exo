param name string
param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Public network access')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

resource eventGridTopic 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: name
  location: location
  tags: union(tags, {
    'Purpose': 'SecretRotationNotifications'
    'Compliance': 'HDS'
  })
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: publicNetworkAccess
  }
}

// Diagnostic settings for Event Grid topic
resource eventGridDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'eventgrid-diagnostics'
  scope: eventGridTopic
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'DeliveryFailures'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'PublishFailures'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

output id string = eventGridTopic.id
output name string = eventGridTopic.name
output endpoint string = eventGridTopic.properties.endpoint
