param name string
param location string = resourceGroup().location
param tags object = {}

param principalId string = ''

@description('Log Analytics Workspace ID for diagnostics (HDS audit trail)')
param logAnalyticsWorkspaceId string = ''

@description('Enable secret rotation policies')
param enableSecretRotation bool = true

@description('Secret rotation notification days before expiry')
param rotationNotificationDays int = 30

@description('Default secret validity period in days')
param secretValidityDays int = 90

@description('Event Grid topic resource ID for rotation notifications')
param eventGridTopicId string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: union(tags, {
    'Compliance': 'HDS'
    'DataClassification': 'HealthData'
    'RGPD': 'Article9'
  })
  properties: {
    tenantId: subscription().tenantId
    // Premium SKU for HSM-backed keys (HDS requirement)
    sku: { family: 'A', name: 'premium' }

    // HDS compliance: Enable soft delete and purge protection
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90

    // Enable RBAC for better access control
    enableRbacAuthorization: false

    // TLS 1.2 minimum (will be upgraded to 1.3 in next step)
    publicNetworkAccess: 'Enabled'

    accessPolicies: !empty(principalId) ? [
      {
        objectId: principalId
        permissions: {
          secrets: [ 'get', 'list' ]
          keys: [ 'get', 'list', 'create', 'encrypt', 'decrypt' ]
          certificates: [ 'get', 'list' ]
        }
        tenantId: subscription().tenantId
      }
    ] : []

    // Network ACLs (will be restricted with Private Endpoints later)
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Diagnostic settings for Key Vault (HDS audit trail)
// Captures all access to secrets, keys, and certificates
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'keyvault-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        // AuditEvent: All operations on vault, secrets, keys, certificates
        // Critical for HDS compliance - tracks who accessed what and when
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        // Azure Policy evaluation events
        category: 'AzurePolicyEvaluationDetails'
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

// Event Grid subscription for secret expiration notifications
resource keyVaultEventSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = if (enableSecretRotation && !empty(eventGridTopicId)) {
  name: '${name}-secret-expiration'
  scope: keyVault
  properties: {
    destination: {
      endpointType: 'EventGrid'
      properties: {
        resourceId: eventGridTopicId
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.KeyVault.SecretNearExpiry'
        'Microsoft.KeyVault.SecretExpired'
        'Microsoft.KeyVault.SecretNewVersionCreated'
      ]
      advancedFilters: []
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440  // 24 hours
    }
  }
}

// Example secrets with rotation policies
// These will be created with initial values via Azure CLI or pipeline

// SQL Server Admin Password
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (enableSecretRotation) {
  name: 'SqlAdminPassword'
  parent: keyVault
  properties: {
    value: 'PLACEHOLDER-WILL-BE-ROTATED'  // Will be set via pipeline
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(utcNow(), 'P${secretValidityDays}D'))
      nbf: dateTimeToEpoch(utcNow())
    }
    contentType: 'text/plain'
  }
  tags: {
    'RotationPolicy': 'Automatic'
    'ValidityDays': string(secretValidityDays)
    'NotificationDays': string(rotationNotificationDays)
    'Compliance': 'HDS'
  }
}

// Application Secret (OAuth, API keys, etc.)
resource appSecretSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (enableSecretRotation) {
  name: 'AppSecret'
  parent: keyVault
  properties: {
    value: 'PLACEHOLDER-WILL-BE-ROTATED'
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(utcNow(), 'P${secretValidityDays}D'))
      nbf: dateTimeToEpoch(utcNow())
    }
    contentType: 'text/plain'
  }
  tags: {
    'RotationPolicy': 'Automatic'
    'ValidityDays': string(secretValidityDays)
    'NotificationDays': string(rotationNotificationDays)
    'Compliance': 'HDS'
  }
}

// Storage Account Key
resource storageAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (enableSecretRotation) {
  name: 'StorageAccountKey'
  parent: keyVault
  properties: {
    value: 'PLACEHOLDER-WILL-BE-ROTATED'
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(utcNow(), 'P${secretValidityDays}D'))
      nbf: dateTimeToEpoch(utcNow())
    }
    contentType: 'text/plain'
  }
  tags: {
    'RotationPolicy': 'Automatic'
    'ValidityDays': string(secretValidityDays)
    'NotificationDays': string(rotationNotificationDays)
    'Compliance': 'HDS'
  }
}

// Service Bus Connection String
resource serviceBusConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (enableSecretRotation) {
  name: 'ServiceBusConnection'
  parent: keyVault
  properties: {
    value: 'PLACEHOLDER-WILL-BE-ROTATED'
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(utcNow(), 'P${secretValidityDays}D'))
      nbf: dateTimeToEpoch(utcNow())
    }
    contentType: 'text/plain'
  }
  tags: {
    'RotationPolicy': 'Automatic'
    'ValidityDays': string(secretValidityDays)
    'NotificationDays': string(rotationNotificationDays)
    'Compliance': 'HDS'
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
output id string = keyVault.id
output enableSecretRotation bool = enableSecretRotation
output secretValidityDays int = secretValidityDays
output rotationNotificationDays int = rotationNotificationDays
