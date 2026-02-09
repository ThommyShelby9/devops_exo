param name string
param location string = 'global'  // Action Groups are global
param tags object = {}

@description('Short name for SMS notifications (max 12 chars)')
param shortName string = 'MedSecure'

@description('Email recipients for alerts')
param emailRecipients array = []

@description('SMS recipients for critical alerts')
param smsRecipients array = []

@description('Webhook URL for integrations (Teams, Slack, etc.)')
param webhookUrl string = ''

@description('Enable Azure Mobile App push notifications')
param enableAppPushNotifications bool = false

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: location
  tags: union(tags, {
    'Purpose': 'SecurityAlerts'
    'Compliance': 'HDS'
  })
  properties: {
    groupShortName: shortName
    enabled: true

    // Email notifications
    emailReceivers: [for (email, i) in emailRecipients: {
      name: 'Email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]

    // SMS notifications (for critical alerts)
    smsReceivers: [for (sms, i) in smsRecipients: {
      name: 'SMS-${i}'
      countryCode: sms.countryCode
      phoneNumber: sms.phoneNumber
    }]

    // Webhook notifications (Teams, Slack, PagerDuty, etc.)
    webhookReceivers: !empty(webhookUrl) ? [
      {
        name: 'Webhook-Integration'
        serviceUri: webhookUrl
        useCommonAlertSchema: true
      }
    ] : []

    // Azure Mobile App push notifications
    azureAppPushReceivers: enableAppPushNotifications ? [
      {
        name: 'AzureApp-SecurityTeam'
        emailAddress: emailRecipients[0]  // Use first email for app linking
      }
    ] : []

    // Azure Function (for custom automation)
    // azureFunctionReceivers: []

    // Logic App (for complex workflows)
    // logicAppReceivers: []

    // ITSM (ServiceNow, etc.)
    // itsmReceivers: []
  }
}

output id string = actionGroup.id
output name string = actionGroup.name
