param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Action Group ID for alert notifications')
param actionGroupId string

@description('Enable security alerts')
param enableSecurityAlerts bool = true

// ============================================
// ALERT 1: Multiple Failed Key Vault Access
// ============================================
resource alertFailedKeyVaultAccess 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-failed-keyvault-access'
  location: location
  tags: union(tags, {
    'AlertType': 'Security'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Multiple Failed Key Vault Access Attempts'
    description: 'Triggers when more than 5 failed Key Vault access attempts detected from same IP in 5 minutes (HDS Article 7.2)'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'  // Every 5 minutes
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.KEYVAULT"
            | where ResultSignature != "OK"
            | where TimeGenerated > ago(5m)
            | summarize FailedAttempts = count() by CallerIPAddress
            | where FailedAttempts > 5
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'SecurityBreach'
        Severity: 'High'
        Compliance: 'HDS-7.2'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 2: SQL Injection Attempt
// ============================================
resource alertSQLInjection 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-sql-injection'
  location: location
  tags: union(tags, {
    'AlertType': 'Security'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Potential SQL Injection Attempt'
    description: 'Triggers when suspicious SQL queries detected (HDS Article 7.2)'
    severity: 1  // Critical
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.SQL"
            | where Category == "SQLSecurityAuditEvents"
            | where statement_s contains "'" or statement_s contains "--" or statement_s contains "OR 1=1"
            | where TimeGenerated > ago(5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'Attack'
        Severity: 'Critical'
        Compliance: 'HDS-7.2'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 3: Unauthorized Data Access
// ============================================
resource alertUnauthorizedAccess 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-unauthorized-access'
  location: location
  tags: union(tags, {
    'AlertType': 'Security'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Multiple Failed Database Access Attempts'
    description: 'Triggers when more than 3 failed database access attempts in 5 minutes (HDS Article 7.2)'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.SQL"
            | where Category == "SQLSecurityAuditEvents"
            | where succeeded_s == "false"
            | where TimeGenerated > ago(5m)
            | summarize FailedAttempts = count() by database_principal_name_s, client_ip_s
            | where FailedAttempts > 3
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'AccessViolation'
        Severity: 'High'
        Compliance: 'HDS-7.2'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 4: Mass Data Export
// ============================================
resource alertMassDataExport 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-mass-data-export'
  location: location
  tags: union(tags, {
    'AlertType': 'Security'
    'Compliance': 'RGPD'
  })
  properties: {
    displayName: 'Potential Mass Data Export'
    description: 'Triggers when more than 100 SELECT queries in 5 minutes (RGPD Article 9)'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.SQL"
            | where Category == "SQLSecurityAuditEvents"
            | where action_name_s == "SELECT"
            | where TimeGenerated > ago(5m)
            | summarize QueryCount = count() by database_principal_name_s, client_ip_s
            | where QueryCount > 100
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'DataBreach'
        Severity: 'High'
        Compliance: 'RGPD-9'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 5: Health Check Failure
// ============================================
resource alertHealthCheckFailure 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-health-check-failure'
  location: location
  tags: union(tags, {
    'AlertType': 'Availability'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Health Check Endpoint Failing'
    description: 'Triggers when health endpoint returns non-200 status (HDS Article 8.1)'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AppServiceHTTPLogs
            | where TimeGenerated > ago(5m)
            | where CsUriStem == "/health"
            | where ScStatus != 200
            | summarize FailureCount = count()
            | where FailureCount > 3
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'Availability'
        Severity: 'High'
        Compliance: 'HDS-8.1'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 6: Application Error Spike
// ============================================
resource alertApplicationErrors 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-application-errors'
  location: location
  tags: union(tags, {
    'AlertType': 'Availability'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Application Error Spike'
    description: 'Triggers when more than 10 HTTP 500 errors per minute (HDS Article 8.1)'
    severity: 3  // Medium
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AppServiceHTTPLogs
            | where TimeGenerated > ago(5m)
            | where ScStatus >= 500
            | summarize ErrorCount = count() by bin(TimeGenerated, 1m)
            | where ErrorCount > 10
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'Performance'
        Severity: 'Medium'
        Compliance: 'HDS-8.1'
      }
    }
    autoMitigate: true
  }
}

// ============================================
// ALERT 7: Secret Expiration Warning
// ============================================
resource alertSecretExpiration 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-secret-expiration'
  location: location
  tags: union(tags, {
    'AlertType': 'Security'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Secret Expiring Soon'
    description: 'Triggers when secrets expire within 7 days (HDS Article 9.1)'
    severity: 4  // Warning
    enabled: true
    evaluationFrequency: 'P1D'  // Daily
    windowSize: 'P1D'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.KEYVAULT"
            | where OperationName == "SecretNearExpiry"
            | where TimeGenerated > ago(1d)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'Maintenance'
        Severity: 'Warning'
        Compliance: 'HDS-9.1'
      }
    }
    autoMitigate: false  // Manual resolution required
  }
}

// ============================================
// ALERT 8: Deployment Failure
// ============================================
resource alertDeploymentFailure 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (enableSecurityAlerts) {
  name: 'alert-deployment-failure'
  location: location
  tags: union(tags, {
    'AlertType': 'Operations'
    'Compliance': 'HDS'
  })
  properties: {
    displayName: 'Deployment Swap Operation Failed'
    description: 'Triggers when Blue/Green deployment swap fails (HDS Article 8.1)'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.WEB"
            | where Category == "AppServiceAuditLogs"
            | where OperationName contains "Swap"
            | where ResultSignature != "OK"
            | where TimeGenerated > ago(15m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
      customProperties: {
        AlertType: 'Deployment'
        Severity: 'High'
        Compliance: 'HDS-8.1'
      }
    }
    autoMitigate: false  // Manual investigation required
  }
}

output alertNames array = [
  alertFailedKeyVaultAccess.name
  alertSQLInjection.name
  alertUnauthorizedAccess.name
  alertMassDataExport.name
  alertHealthCheckFailure.name
  alertApplicationErrors.name
  alertSecretExpiration.name
  alertDeploymentFailure.name
]
