param name string
param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics Workspace ID for Application Insights')
param logAnalyticsWorkspaceId string

@description('Application type')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

@description('Sampling percentage (100 = no sampling, required for HDS compliance)')
@minValue(0)
@maxValue(100)
param samplingPercentage int = 100

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: applicationType
  tags: union(tags, {
    'Compliance': 'HDS'
    'Monitoring': 'RealTime'
    'SLO': '99.95'
  })
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId

    // HDS compliance: 100% sampling for full audit trail
    SamplingPercentage: samplingPercentage

    // Retention: 90 days minimum for HDS
    RetentionInDays: 90

    // Disable IP masking for security audit (authorized in HDS context)
    DisableIpMasking: false

    // Enable ingestion and query
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = applicationInsights.id
output name string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
