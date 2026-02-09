// ============================================
// Application Insights
// Application Performance Monitoring (APM)
// HDS Article 8.1 - Service Availability Monitoring
// ============================================

param name string
param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics Workspace ID for Application Insights')
param logAnalyticsWorkspaceId string

@description('Application type')
@allowed(['web', 'other'])
param applicationType string = 'web'

@description('Retention in days (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90  // HDS: 90 days minimum

@description('Daily cap in GB (0 = no cap)')
param dailyQuotaGb int = 10

@description('Sampling percentage (1-100)')
@minValue(1)
@maxValue(100)
param samplingPercentage int = 100  // No sampling by default

@description('Enable public network access')
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Enable public network access for query')
param publicNetworkAccessForQuery string = 'Enabled'

@description('Disable local authentication (use Azure AD only)')
param disableLocalAuth bool = true  // HDS: Azure AD authentication

// ============================================
// Application Insights Resource
// ============================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: union(tags, {
    'Purpose': 'ApplicationMonitoring'
    'Compliance': 'HDS'
    'DataClassification': 'OperationalData'
  })
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId

    // Retention and quota
    RetentionInDays: retentionInDays
    IngestionMode: 'LogAnalytics'  // Use Log Analytics for storage

    // Sampling
    SamplingPercentage: samplingPercentage

    // Network access
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery

    // Authentication (HDS: Azure AD only)
    DisableLocalAuth: disableLocalAuth

    // Daily cap
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

// ============================================
// Smart Detection - Anomaly Detection Rules
// ============================================

// Failure Anomalies (automatic)
resource smartDetectionFailure 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'FailureAnomaliesDetector'
  parent: appInsights
  properties: {
    name: 'Failure Anomalies'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
    ruleDefinitions: {
      Name: 'Failure Anomalies'
      DisplayName: 'Failure Anomalies'
      Description: 'Detects unusual rise in the rate of failed requests or dependency calls'
      HelpUrl: 'https://docs.microsoft.com/azure/application-insights/app-insights-proactive-failure-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
  }
}

// Response Time Degradation
resource smartDetectionResponseTime 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'SlowPageLoadTimeDetector'
  parent: appInsights
  properties: {
    name: 'Slow page load time'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
    ruleDefinitions: {
      Name: 'Slow page load time'
      DisplayName: 'Slow page load time'
      Description: 'Detects when page load performance is degrading'
      HelpUrl: 'https://docs.microsoft.com/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
  }
}

// Slow Server Response Time
resource smartDetectionSlowServer 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'SlowServerResponseTimeDetector'
  parent: appInsights
  properties: {
    name: 'Slow server response time'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
    ruleDefinitions: {
      Name: 'Slow server response time'
      DisplayName: 'Slow server response time'
      Description: 'Detects when server response time is degrading'
      HelpUrl: 'https://docs.microsoft.com/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
  }
}

// Memory Leak Detection
resource smartDetectionMemoryLeak 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'LongDependencyDurationDetector'
  parent: appInsights
  properties: {
    name: 'Long dependency duration'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
    ruleDefinitions: {
      Name: 'Long dependency duration'
      DisplayName: 'Long dependency duration'
      Description: 'Detects when dependency call duration is degrading'
      HelpUrl: 'https://docs.microsoft.com/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
  }
}

// Exception Volume
resource smartDetectionExceptions 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'ExceptionVolumeChangedDetector'
  parent: appInsights
  properties: {
    name: 'Abnormal rise in exception volume'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
    ruleDefinitions: {
      Name: 'Abnormal rise in exception volume'
      DisplayName: 'Abnormal rise in exception volume'
      Description: 'Detects unusual rise in the rate of exceptions'
      HelpUrl: 'https://docs.microsoft.com/azure/application-insights/app-insights-proactive-exception-volume'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
  }
}

// ============================================
// Daily Cap
// ============================================
resource dailyCap 'Microsoft.Insights/components/CurrentBillingFeatures@2015-05-01' = {
  name: 'dailyCap'
  parent: appInsights
  properties: {
    CurrentBillingFeatures: ['Basic']
    DataVolumeCap: {
      Cap: dailyQuotaGb
      WarningThreshold: 90  // Alert at 90% of daily cap
      ResetTime: 0  // Reset at midnight UTC
    }
  }
}

// ============================================
// Outputs
// ============================================
output id string = appInsights.id
output name string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
output connectionString string = appInsights.properties.ConnectionString
output appId string = appInsights.properties.AppId
