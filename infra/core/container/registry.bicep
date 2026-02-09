param name string
param location string = resourceGroup().location
param tags object = {}

@description('SKU for Container Registry - Premium recommended for HDS (geo-replication, private endpoints)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Premium'

@description('Enable admin user (NOT recommended for production, use Managed Identity)')
param adminUserEnabled bool = false

@description('Enable zone redundancy (Premium only)')
param zoneRedundancy bool = false

@description('Enable anonymous pull (NOT recommended for HDS)')
param anonymousPullEnabled bool = false

@description('Enable public network access (will be disabled with Private Endpoints)')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: name
  location: location
  tags: union(tags, {
    'Compliance': 'HDS'
    'Purpose': 'ContainerImages'
    'Security': 'ScanEnabled'
  })
  sku: {
    name: sku
  }
  properties: {
    // Security: Disable admin user, use Managed Identity only
    adminUserEnabled: adminUserEnabled

    // Network security
    publicNetworkAccess: publicNetworkAccess
    networkRuleBypassOptions: 'AzureServices'

    // Zone redundancy for high availability (Premium only)
    zoneRedundancy: sku == 'Premium' ? (zoneRedundancy ? 'Enabled' : 'Disabled') : 'Disabled'

    // Anonymous pull disabled for HDS compliance
    anonymousPullEnabled: anonymousPullEnabled

    // Data endpoint per region (Premium only)
    dataEndpointEnabled: sku == 'Premium'

    // Policies
    policies: {
      // Quarantine policy: images must pass security scan before being available
      quarantinePolicy: {
        status: 'enabled'
      }
      // Trust policy: only signed images (Docker Content Trust)
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      // Retention policy: keep untagged manifests for 7 days
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
      // Export policy: control where images can be exported
      exportPolicy: {
        status: 'enabled'
      }
    }

    // Encryption with customer-managed keys (can be configured later)
    encryption: {
      status: 'disabled'
    }
  }
}

// Diagnostic settings for ACR (HDS audit trail)
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'acr-diagnostics'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'ContainerRegistryLoginEvents'
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

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
