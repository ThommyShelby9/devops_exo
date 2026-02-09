// ============================================
// TDE (Transparent Data Encryption) Key
// Customer-Managed Key (CMK) for SQL Database
// ============================================

param keyVaultName string
param location string = resourceGroup().location
param tags object = {}

@description('Name of the TDE encryption key')
param tdeKeyName string = 'TDE-Key'

@description('Key size in bits (2048, 3072, or 4096)')
@allowed([2048, 3072, 4096])
param keySize int = 4096  // HDS: Maximum security

@description('Key type')
@allowed(['RSA', 'RSA-HSM'])
param keyType string = 'RSA'  // Use RSA-HSM for production (requires Premium Key Vault)

@description('Key expiration date (ISO 8601 format)')
param expiryDate string = ''

@description('SQL Server Principal ID for Key Vault access')
param sqlServerPrincipalId string

@description('Enable automatic key rotation')
param enableAutoRotation bool = true

@description('Rotation policy lifetime in days (HDS: 90-365 days recommended)')
param rotationLifetimeDays int = 365

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// ============================================
// TDE Encryption Key
// ============================================
resource tdeKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: tdeKeyName
  parent: keyVault
  tags: union(tags, {
    'Purpose': 'TDE'
    'Compliance': 'HDS'
    'DataClassification': 'HealthData'
  })
  properties: {
    kty: keyType
    keySize: keySize
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: true
      exp: !empty(expiryDate) ? dateTimeToEpoch(expiryDate) : null
    }
    // Rotation policy (HDS Article 9.1)
    rotationPolicy: enableAutoRotation ? {
      attributes: {
        expiryTime: 'P${rotationLifetimeDays}D'  // Expiry after X days
      }
      lifetimeActions: [
        {
          trigger: {
            timeBeforeExpiry: 'P30D'  // Rotate 30 days before expiry
          }
          action: {
            type: 'Rotate'
          }
        }
        {
          trigger: {
            timeBeforeExpiry: 'P7D'  // Notify 7 days before expiry
          }
          action: {
            type: 'Notify'
          }
        }
      ]
    } : null
  }
}

// ============================================
// Key Vault Access Policy for SQL Server
// Grant SQL Server Managed Identity access to the TDE key
// ============================================
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: sqlServerPrincipalId
        permissions: {
          keys: [
            'get'
            'wrapKey'
            'unwrapKey'
          ]
          // Note: SQL Server only needs get, wrapKey, unwrapKey for TDE
          // DO NOT grant additional permissions (least privilege principle)
        }
      }
    ]
  }
}

// ============================================
// Outputs
// ============================================
output keyId string = tdeKey.properties.keyUri
output keyName string = tdeKey.name
output keyVersion string = tdeKey.properties.keyUriWithVersion
output keyVaultUri string = keyVault.properties.vaultUri
