param name string
param location string = resourceGroup().location
param tags object = {}

param appUser string = 'appUser'
param databaseName string
param keyVaultName string
param sqlAdmin string = 'sqlAdmin'
param connectionStringKey string = 'AZURE-SQL-CONNECTION-STRING'

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Enable TDE with Customer-Managed Keys (CMK)')
param enableTdeCmk bool = true

@description('Key Vault Resource ID for TDE CMK')
param keyVaultResourceId string = ''

@description('TDE Protector Key Name in Key Vault')
param tdeKeyName string = 'TDE-Key'

@description('TDE Protector Key Version (leave empty for latest)')
param tdeKeyVersion string = ''

@secure()
param sqlAdminPassword string
@secure()
param appUserPassword string

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: name
  location: location
  tags: union(tags, {
    'Compliance': 'HDS'
    'DataClassification': 'HealthData'
    'Encryption': 'TDE-CMK-AlwaysEncrypted'
  })
  // Managed Identity for Key Vault access (TDE CMK requirement)
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    version: '12.0'
    // HDS requirement: TLS 1.3 minimum (upgraded from 1.2)
    minimalTlsVersion: '1.3'
    publicNetworkAccess: 'Enabled'
    administratorLogin: sqlAdmin
    administratorLoginPassword: sqlAdminPassword
    // Azure AD authentication can be configured post-deployment
  }

  resource database 'databases' = {
    name: databaseName
    location: location
    tags: union(tags, {
      'Compliance': 'HDS'
      'Encryption': 'TDE'
    })
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      maxSizeBytes: 2147483648 // 2GB
      catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
      zoneRedundant: false
      readScale: 'Disabled'
      requestedBackupStorageRedundancy: 'Local'
    }
  }

  // TDE Encryption Key (Customer-Managed Key from Key Vault)
  resource encryptionProtector 'encryptionProtector' = if (enableTdeCmk && !empty(keyVaultResourceId)) {
    name: 'current'
    properties: {
      serverKeyType: 'AzureKeyVault'
      serverKeyName: !empty(tdeKeyVersion)
        ? '${keyVaultName}_${tdeKeyName}_${tdeKeyVersion}'
        : '${keyVaultName}_${tdeKeyName}'
      autoRotationEnabled: true  // HDS requirement: automatic key rotation
    }
    dependsOn: [
      serverKey
    ]
  }

  // Server Key resource (links to Key Vault key)
  resource serverKey 'keys' = if (enableTdeCmk && !empty(keyVaultResourceId)) {
    name: !empty(tdeKeyVersion)
      ? '${keyVaultName}_${tdeKeyName}_${tdeKeyVersion}'
      : '${keyVaultName}_${tdeKeyName}'
    properties: {
      serverKeyType: 'AzureKeyVault'
      uri: !empty(tdeKeyVersion)
        ? '${keyVaultResourceId}/keys/${tdeKeyName}/${tdeKeyVersion}'
        : '${keyVaultResourceId}/keys/${tdeKeyName}'
    }
  }

  // Enable TDE (Transparent Data Encryption) - HDS requirement
  resource transparentDataEncryption 'databases/transparentDataEncryption' = {
    parent: database
    name: 'current'
    properties: {
      state: 'Enabled'
    }
    dependsOn: [
      encryptionProtector
    ]
  }

  // Firewall: Allow only Azure services (HDS security)
  // For production, use Private Endpoints instead
  resource firewall 'firewallRules' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      // Allow only Azure-hosted services (0.0.0.0-0.0.0.0)
      // For development, add specific IP ranges via parameters
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

// Diagnostic settings for SQL Server (HDS audit trail)
resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'sql-diagnostics'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'DevOpsOperationsAudit'
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

// Diagnostic settings for SQL Database (HDS compliance)
resource databaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'database-diagnostics'
  scope: sqlServer::database
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AutomaticTuning'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'Timeouts'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'Blocks'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'Deadlocks'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'WorkloadManagement'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

resource sqlDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${name}-deployment-script'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.37.0'
    retentionInterval: 'PT1H' // Retain the script resource for 1 hour after it ends running
    timeout: 'PT5M' // Five minutes
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'APPUSERNAME'
        value: appUser
      }
      {
        name: 'APPUSERPASSWORD'
        secureValue: appUserPassword
      }
      {
        name: 'DBNAME'
        value: databaseName
      }
      {
        name: 'DBSERVER'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'SQLCMDPASSWORD'
        secureValue: sqlAdminPassword
      }
      {
        name: 'SQLADMIN'
        value: sqlAdmin
      }
    ]

    scriptContent: '''
wget https://github.com/microsoft/go-sqlcmd/releases/download/v0.8.1/sqlcmd-v0.8.1-linux-x64.tar.bz2
tar x -f sqlcmd-v0.8.1-linux-x64.tar.bz2 -C .

cat <<SCRIPT_END > ./initDb.sql
drop user ${APPUSERNAME}
go
create user ${APPUSERNAME} with password = '${APPUSERPASSWORD}'
go
alter role db_owner add member ${APPUSERNAME}
go
SCRIPT_END

./sqlcmd -S ${DBSERVER} -d ${DBNAME} -U ${SQLADMIN} -i ./initDb.sql
    '''
  }
}

resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'sqlAdminPassword'
  properties: {
    value: sqlAdminPassword
  }
}

resource appUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'appUserPassword'
  properties: {
    value: appUserPassword
  }
}

resource sqlAzureConnectionStringSercret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: connectionStringKey
  properties: {
    value: '${connectionString}; Password=${appUserPassword}'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

var connectionString = 'Server=${sqlServer.properties.fullyQualifiedDomainName}; Database=${sqlServer::database.name}; User=${appUser}'

output connectionStringKey string = connectionStringKey
output databaseName string = sqlServer::database.name
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerIdentity string = sqlServer.identity.principalId
