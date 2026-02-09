param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
param reserved bool = true

@description('SKU for App Service Plan - S1 minimum for HDS (deployment slots, auto-scaling, 99.95% SLA)')
param sku object = {
  name: 'S1'
  tier: 'Standard'
  capacity: 1
}

@description('Enable zone redundancy for high availability (requires Premium SKU)')
param zoneRedundant bool = false

@description('Maximum elastic worker count for auto-scaling')
@minValue(1)
@maxValue(20)
param maximumElasticWorkerCount int = 3

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, {
    'Compliance': 'HDS'
    'SLA': '99.95'
    'Tier': sku.tier
  })
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
    // Zone redundancy for high availability (Premium tier only)
    zoneRedundant: zoneRedundant
    // Elastic scale for auto-scaling
    maximumElasticWorkerCount: maximumElasticWorkerCount
    // Per-site scaling allows individual apps to scale independently
    perSiteScaling: false
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
output sku string = sku.name
