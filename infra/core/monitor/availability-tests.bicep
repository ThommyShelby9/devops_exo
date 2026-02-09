// ============================================
// Application Insights Availability Tests
// Web Tests for Health Monitoring
// HDS Article 8.1 - Service Availability
// ============================================

param location string
param tags object = {}

@description('Application Insights resource ID')
param appInsightsId string

@description('Application Insights name')
param appInsightsName string

@description('Web app URL to test')
param webAppUrl string

@description('Action Group ID for alert notifications')
param actionGroupId string

@description('Enable availability tests')
param enableAvailabilityTests bool = true

@description('Test frequency in seconds')
@allowed([300, 600, 900])
param testFrequency int = 300  // 5 minutes

@description('Test timeout in seconds')
@minValue(30)
@maxValue(120)
param testTimeout int = 30

@description('Test locations (geo-distributed)')
param testLocations array = [
  {
    Id: 'emea-fr-pra-edge'  // France Central
  }
  {
    Id: 'emea-nl-ams-azr'  // West Europe
  }
  {
    Id: 'emea-gb-db3-azr'  // UK South
  }
  {
    Id: 'us-va-ash-azr'  // East US
  }
  {
    Id: 'apac-sg-sin-azr'  // Southeast Asia
  }
]

// ============================================
// AVAILABILITY TEST 1: Home Page
// ============================================
resource availabilityTestHomePage 'Microsoft.Insights/webtests@2022-06-15' = if (enableAvailabilityTests) {
  name: 'webtest-homepage'
  location: location
  tags: union(tags, {
    'hidden-link:${appInsightsId}': 'Resource'
    'TestType': 'AvailabilityTest'
    'Compliance': 'HDS'
  })
  kind: 'standard'
  properties: {
    Name: 'MedSecure - Home Page Availability'
    Description: 'Tests home page availability from multiple global locations (HDS Article 8.1)'
    Enabled: true
    Frequency: testFrequency
    Timeout: testTimeout
    Kind: 'standard'
    RetryEnabled: true
    Locations: testLocations

    Request: {
      RequestUrl: webAppUrl
      HttpVerb: 'GET'
      Headers: []
      ParseDependentRequests: false
      FollowRedirects: true
    }

    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7  // Alert if cert expires in 7 days
      ContentValidation: {
        ContentMatch: 'MedSecure'  // Check for expected content
        IgnoreCase: true
        PassIfTextFound: true
      }
    }
  }
}

// ============================================
// AVAILABILITY TEST 2: Health Endpoint
// ============================================
resource availabilityTestHealth 'Microsoft.Insights/webtests@2022-06-15' = if (enableAvailabilityTests) {
  name: 'webtest-health'
  location: location
  tags: union(tags, {
    'hidden-link:${appInsightsId}': 'Resource'
    'TestType': 'HealthCheck'
    'Compliance': 'HDS'
  })
  kind: 'standard'
  properties: {
    Name: 'MedSecure - Health Endpoint'
    Description: 'Tests health endpoint availability (HDS Article 8.1)'
    Enabled: true
    Frequency: testFrequency
    Timeout: testTimeout
    Kind: 'standard'
    RetryEnabled: true
    Locations: testLocations

    Request: {
      RequestUrl: '${webAppUrl}/health'
      HttpVerb: 'GET'
      Headers: []
      ParseDependentRequests: false
      FollowRedirects: false
    }

    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7
      ContentValidation: {
        ContentMatch: 'Healthy'
        IgnoreCase: true
        PassIfTextFound: true
      }
    }
  }
}

// ============================================
// AVAILABILITY TEST 3: API Endpoint
// ============================================
resource availabilityTestApi 'Microsoft.Insights/webtests@2022-06-15' = if (enableAvailabilityTests) {
  name: 'webtest-api'
  location: location
  tags: union(tags, {
    'hidden-link:${appInsightsId}': 'Resource'
    'TestType': 'APITest'
    'Compliance': 'HDS'
  })
  kind: 'standard'
  properties: {
    Name: 'MedSecure - API Availability'
    Description: 'Tests API endpoint availability'
    Enabled: true
    Frequency: testFrequency
    Timeout: testTimeout
    Kind: 'standard'
    RetryEnabled: true
    Locations: testLocations

    Request: {
      RequestUrl: '${webAppUrl}/api/health'
      HttpVerb: 'GET'
      Headers: [
        {
          name: 'Accept'
          value: 'application/json'
        }
      ]
      ParseDependentRequests: false
      FollowRedirects: false
    }

    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7
    }
  }
}

// ============================================
// ALERT: Availability Test Failed
// ============================================
resource alertAvailabilityTestFailed 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAvailabilityTests) {
  name: 'alert-availability-test-failed'
  location: 'global'
  tags: union(tags, {
    'AlertType': 'Availability'
    'Compliance': 'HDS'
  })
  properties: {
    description: 'Triggers when availability test fails from 2+ locations (HDS Article 8.1)'
    severity: 1  // Critical
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT1M'  // Every minute
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: availabilityTestHomePage.id
      componentId: appInsightsId
      failedLocationCount: 2  // Alert if fails from 2+ locations
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'AvailabilityTestFailure'
          Severity: 'Critical'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}

// ============================================
// Outputs
// ============================================
output webTestNames array = [
  availabilityTestHomePage.name
  availabilityTestHealth.name
  availabilityTestApi.name
]

output alertName string = alertAvailabilityTestFailed.name
