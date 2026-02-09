# Guide Audit Trail Key Vault pour MedSecure

## 📋 Vue d'ensemble

Le Key Vault de MedSecure est configuré pour logger tous les accès aux secrets, clés et certificats dans Log Analytics. Cette traçabilité est **obligatoire pour la certification HDS**.

## 🔍 Événements capturés

### AuditEvent - Tous les accès

**Types d'opérations loggées :**
- ✅ `SecretGet` : Lecture d'un secret
- ✅ `SecretSet` : Création/Mise à jour d'un secret
- ✅ `SecretDelete` : Suppression d'un secret
- ✅ `KeySign` : Signature avec une clé
- ✅ `KeyVerify` : Vérification de signature
- ✅ `KeyEncrypt` : Chiffrement avec une clé
- ✅ `KeyDecrypt` : Déchiffrement avec une clé
- ✅ `CertificateGet` : Lecture d'un certificat
- ✅ `VaultGet` : Lecture des propriétés du vault

### Métadonnées capturées

Chaque événement contient :
- **TimeGenerated** : Timestamp UTC
- **CallerIPAddress** : IP source
- **Identity** : Principal ID (Managed Identity, User, Service Principal)
- **OperationName** : Type d'opération
- **ResultType** : Success ou Failure
- **ResultDescription** : Détails de l'erreur si échec
- **ResourceId** : Ressource Key Vault
- **SecretName** : Nom du secret accédé (si applicable)

## 📊 Requêtes KQL (Kusto Query Language)

### 1. Tous les accès aux secrets (24h)

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(24h)
| where OperationName startswith "Secret"
| project TimeGenerated, CallerIPAddress, identity_claim_appid_g, OperationName, ResultType, id_s
| order by TimeGenerated desc
```

### 2. Échecs d'accès (incidents de sécurité)

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(7d)
| where ResultType == "Unauthorized" or ResultType == "Forbidden"
| summarize FailedAttempts = count() by CallerIPAddress, identity_claim_appid_g, OperationName
| where FailedAttempts > 5
| order by FailedAttempts desc
```

### 3. Secrets les plus accédés

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName == "SecretGet"
| where TimeGenerated > ago(30d)
| summarize AccessCount = count() by id_s
| order by AccessCount desc
| take 10
```

### 4. Accès en dehors des heures de bureau

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(7d)
| extend Hour = datetime_part("hour", TimeGenerated)
| where Hour < 7 or Hour > 20  // En dehors de 7h-20h
| project TimeGenerated, CallerIPAddress, identity_claim_appid_g, OperationName, id_s
| order by TimeGenerated desc
```

### 5. Modifications de secrets (audit trail)

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName in ("SecretSet", "SecretDelete")
| where TimeGenerated > ago(30d)
| project TimeGenerated, CallerIPAddress, identity_claim_appid_g, OperationName, id_s, ResultType
| order by TimeGenerated desc
```

### 6. Accès depuis IP suspectes

```kusto
let SuspiciousIPs = dynamic(["1.2.3.4", "5.6.7.8"]); // IP à bloquer
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where CallerIPAddress in (SuspiciousIPs)
| project TimeGenerated, CallerIPAddress, OperationName, ResultType, id_s
| order by TimeGenerated desc
```

### 7. Dashboard HDS - Vue d'ensemble (7 jours)

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(7d)
| summarize
    TotalOperations = count(),
    SuccessfulOperations = countif(ResultType == "Success"),
    FailedOperations = countif(ResultType != "Success"),
    UniqueCallers = dcount(identity_claim_appid_g),
    UniqueIPs = dcount(CallerIPAddress)
| extend SuccessRate = (SuccessfulOperations * 100.0 / TotalOperations)
```

## 🚨 Alertes de sécurité recommandées

### Alerte 1 : Échecs d'authentification répétés

**Bicep Configuration :**
```bicep
resource failedAuthAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'kv-failed-auth-alert'
  location: location
  properties: {
    displayName: 'Key Vault - Failed Authentication Attempts'
    description: 'Alert when more than 5 failed authentication attempts in 5 minutes'
    severity: 2  // Warning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalytics.id
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.KEYVAULT"
            | where ResultType != "Success"
            | summarize FailedCount = count() by CallerIPAddress
            | where FailedCount > 5
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
  }
}
```

### Alerte 2 : Suppression de secrets

```bicep
resource secretDeletionAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'kv-secret-deletion-alert'
  location: location
  properties: {
    displayName: 'Key Vault - Secret Deletion'
    description: 'Alert on any secret deletion (HDS critical event)'
    severity: 1  // Error
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalytics.id
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.KEYVAULT"
            | where OperationName == "SecretDelete"
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
  }
}
```

### Alerte 3 : Accès depuis IP inconnue

```bicep
resource unknownIPAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'kv-unknown-ip-alert'
  location: location
  properties: {
    displayName: 'Key Vault - Access from Unknown IP'
    description: 'Alert when Key Vault is accessed from IP not in whitelist'
    severity: 2  // Warning
    enabled: true
    evaluationFrequency: 'PT15M'
    scopes: [
      logAnalytics.id
    ]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            let KnownIPs = dynamic(["52.1.2.3", "52.4.5.6"]); // Azure App Service IPs
            AzureDiagnostics
            | where ResourceProvider == "MICROSOFT.KEYVAULT"
            | where CallerIPAddress !in (KnownIPs)
            | where CallerIPAddress != ""
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
  }
}
```

## 📈 Workbook pour Dashboard HDS

### Template Azure Workbook

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureDiagnostics\n| where ResourceProvider == \"MICROSOFT.KEYVAULT\"\n| where TimeGenerated > ago(7d)\n| summarize Count = count() by bin(TimeGenerated, 1h)\n| render timechart",
        "size": 0,
        "title": "Key Vault Operations (7 days)",
        "timeContext": {
          "durationMs": 604800000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureDiagnostics\n| where ResourceProvider == \"MICROSOFT.KEYVAULT\"\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by OperationName\n| order by Count desc\n| take 10",
        "size": 0,
        "title": "Top 10 Operations (24h)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "piechart"
      }
    }
  ]
}
```

## ✅ Checklist Audit HDS

### Logs obligatoires
- [x] **AuditEvent activé** : Tous les accès loggés
- [x] **Rétention 90 jours** : Conformité HDS minimum
- [x] **Log Analytics** : Centralisation des logs
- [x] **Diagnostic settings** : Configurés sur le Key Vault

### Alertes recommandées
- [ ] **Échecs d'authentification** : > 5 tentatives en 5 min
- [ ] **Suppression de secrets** : Alerte immédiate
- [ ] **Accès IP inconnue** : Hors whitelist Azure
- [ ] **Accès hors heures** : En dehors de 7h-20h

### Monitoring
- [ ] **Dashboard créé** : Vue d'ensemble des opérations
- [ ] **Workbook HDS** : Métriques de conformité
- [ ] **Revue mensuelle** : Analyse des logs d'accès

## 🔐 Conformité RGPD

### Données personnelles dans les logs

**PII potentiellement présentes :**
- ❌ **CallerIPAddress** : Adresse IP (donnée personnelle)
- ✅ **SecretName** : Pas de PII (noms techniques uniquement)
- ✅ **Identity** : Object ID (pas directement identifiant)

**Anonymisation si nécessaire :**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| extend AnonymizedIP = hash_sha256(tostring(CallerIPAddress))
| project TimeGenerated, AnonymizedIP, OperationName, ResultType
```

## 📚 Rapports d'audit HDS

### Rapport mensuel - Accès aux données de santé

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > startofmonth(now())
| summarize
    TotalAccess = count(),
    UniqueUsers = dcount(identity_claim_appid_g),
    SuccessRate = (countif(ResultType == "Success") * 100.0 / count())
    by bin(TimeGenerated, 1d)
| order by TimeGenerated asc
```

### Export pour auditeur externe

```bash
# Export logs pour audit HDS
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' | where TimeGenerated > ago(90d)" \
  --output json > keyvault-audit-90days.json
```

## 📚 Ressources

- [Azure Key Vault Logging](https://learn.microsoft.com/azure/key-vault/general/logging)
- [Log Analytics Query Language](https://learn.microsoft.com/azure/azure-monitor/logs/get-started-queries)
- [HDS Audit Requirements](https://esante.gouv.fr/labels-certifications/hds)
- [RGPD Article 32](https://www.cnil.fr/fr/reglement-europeen-protection-donnees/chapitre4#Article32)

## ✅ Validation

Pour valider que l'audit trail fonctionne :

```bash
# 1. Accéder à un secret
az keyvault secret show --vault-name <vault-name> --name sqlAdminPassword

# 2. Attendre 5-10 minutes (ingestion Log Analytics)

# 3. Vérifier dans Log Analytics
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' | where TimeGenerated > ago(15m) | order by TimeGenerated desc"
```

**Résultat attendu :** L'opération `SecretGet` doit apparaître dans les logs avec votre IP et votre identité.
