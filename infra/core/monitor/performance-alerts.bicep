// ============================================
// Application Insights Performance Alerts
// HDS Article 8.1 - Service Availability
// ============================================

param location string = 'global'
param tags object = {}

@description('Application Insights resource ID')
param appInsightsId string

@description('Application Insights name')
param appInsightsName string

@description('Action Group ID for alert notifications')
param actionGroupId string

@description('Enable performance alerts')
param enablePerformanceAlerts bool = true

// ============================================
// ALERT 1: High Response Time
// ============================================
resource alertHighResponseTime 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-response-time'
  location: location
  tags: union(tags, {
    'AlertType': 'Performance'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when average server response time exceeds 2 seconds (HDS Article 8.1)'
    severity: 2  // High
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'  // Every 5 minutes
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ResponseTime'
          metricName: 'requests/duration'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 2000  // 2 seconds in milliseconds
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'PerformanceDegradation'
          Severity: 'High'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 2: High Error Rate
// ============================================
resource alertHighErrorRate 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-error-rate'
  location: location
  tags: union(tags, {
    'AlertType': 'Availability'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when request failure rate exceeds 5% (HDS Article 8.1)'
    severity: 1  // Critical
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailureRate'
          metricName: 'requests/failed'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 5  // 5% failure rate
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'HighErrorRate'
          Severity: 'Critical'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 3: Low Availability
// ============================================
resource alertLowAvailability 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-low-availability'
  location: location
  tags: union(tags, {
    'AlertType': 'Availability'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when application availability drops below 99% (HDS Article 8.1)'
    severity: 1  // Critical
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'  // Longer window for availability
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Availability'
          metricName: 'availabilityResults/availabilityPercentage'
          metricNamespace: 'microsoft.insights/components'
          operator: 'LessThan'
          threshold: 99  // 99% SLA
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'AvailabilityIssue'
          Severity: 'Critical'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 4: High Dependency Duration
// ============================================
resource alertHighDependencyDuration 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-dependency-duration'
  location: location
  tags: union(tags, {
    'AlertType': 'Performance'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when dependency call duration exceeds 5 seconds'
    severity: 3  // Medium
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DependencyDuration'
          metricName: 'dependencies/duration'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 5000  // 5 seconds in milliseconds
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'DependencyPerformance'
          Severity: 'Medium'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 5: High Server Exceptions
// ============================================
resource alertHighExceptions 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-exceptions'
  location: location
  tags: union(tags, {
    'AlertType': 'Reliability'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when server exceptions exceed 10 per minute'
    severity: 2  // High
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ExceptionCount'
          metricName: 'exceptions/server'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'ExceptionSpike'
          Severity: 'High'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 6: Memory Usage High
// ============================================
resource alertHighMemory 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-memory'
  location: location
  tags: union(tags, {
    'AlertType': 'Resource'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when available memory drops below 20%'
    severity: 2  // High
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'MemoryUsage'
          metricName: 'performanceCounters/availableMemory'
          metricNamespace: 'microsoft.insights/components'
          operator: 'LessThan'
          threshold: 20  // 20% available memory
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'ResourcePressure'
          Severity: 'High'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// ALERT 7: CPU Usage High
// ============================================
resource alertHighCpu 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts) {
  name: 'alert-high-cpu'
  location: location
  tags: union(tags, {
    'AlertType': 'Resource'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when CPU usage exceeds 80%'
    severity: 3  // Medium
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'CpuUsage'
          metricName: 'performanceCounters/processCpuPercentage'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 80  // 80% CPU
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'ResourcePressure'
          Severity: 'Medium'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// Outputs
// ============================================
output alertNames array = [
  alertHighResponseTime.name
  alertHighErrorRate.name
  alertLowAvailability.name
  alertHighDependencyDuration.name
  alertHighExceptions.name
  alertHighMemory.name
  alertHighCpu.name
]
