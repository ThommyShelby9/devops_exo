# Guide Audit Trail et Journalisation HDS - MedSecure

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Requêtes KQL](#requêtes-kql)
4. [Alertes Azure Monitor](#alertes-azure-monitor)
5. [Rapports de conformité](#rapports-de-conformité)
6. [Conformité HDS](#conformité-hds)
7. [Utilisation](#utilisation)

---

## 🎯 Vue d'ensemble

### Objectifs HDS

| Article HDS | Exigence | Implémentation |
|-------------|----------|----------------|
| **4.1** | Traçabilité des accès | Log Analytics 90 jours ✅ |
| **4.2** | Conservation des logs | Retention policy 90j ✅ |
| **7.2** | Détection des menaces | 15 alertes temps réel ✅ |
| **8.1** | Disponibilité | Monitoring continu ✅ |
| **9.1** | Gestion des secrets | Rotation tracking ✅ |

### Sources de logs

```
Azure Log Analytics Workspace
├─ AzureDiagnostics (Key Vault, SQL, App Service)
├─ AppServiceHTTPLogs (HTTP requests)
├─ AppServiceConsoleLogs (Application logs)
├─ AppServiceAuditLogs (Deployment history)
└─ Perf (Performance counters)
```

**Retention** : 90 jours (exigence HDS)

---

## 🏗️ Architecture

### Flux de journalisation

```
┌─────────────────────────────────────────────┐
│  Azure Resources                            │
│  ├─ Key Vault                               │
│  ├─ SQL Database                            │
│  ├─ App Service                             │
│  └─ Storage Account                         │
└─────────────────────────────────────────────┘
                    ↓ (Diagnostic Settings)
┌─────────────────────────────────────────────┐
│  Log Analytics Workspace                    │
│  - Retention: 90 days                       │
│  - Tables: AzureDiagnostics, AppServiceLogs │
└─────────────────────────────────────────────┘
                    ↓ (KQL Queries)
┌─────────────────────────────────────────────┐
│  Azure Monitor Alerts                       │
│  - 15 security alerts                       │
│  - Real-time detection                      │
└─────────────────────────────────────────────┘
                    ↓ (Notifications)
┌─────────────────────────────────────────────┐
│  Action Group                               │
│  ├─ Email                                   │
│  ├─ SMS                                     │
│  ├─ Webhook (Teams/Slack)                   │
│  └─ Azure App Push                          │
└─────────────────────────────────────────────┘
```

---

## 📊 Requêtes KQL

**Fichier** : `monitoring/kql-queries/hds-audit-trail.kql`

### 16 requêtes principales

#### 1. Key Vault Access Audit (HDS 4.1)

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(90d)
| project TimeGenerated, OperationName, CallerIPAddress,
          User = identity_claim_upn_s,
          SecretName = properties_objectName_s,
          ResultSignature
| order by TimeGenerated desc
```

**Usage** : Traçabilité complète des accès aux secrets

#### 2. Failed Access Attempts (HDS 7.2)

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultSignature != "OK"
| where TimeGenerated > ago(7d)
| project TimeGenerated, OperationName, CallerIPAddress,
          User = identity_claim_upn_s,
          SecretName = properties_objectName_s
| order by TimeGenerated desc
```

**Usage** : Détection des tentatives d'accès non autorisées

#### 3. SQL Database Access (HDS 4.1 + RGPD 9)

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "SQLSecurityAuditEvents"
| where TimeGenerated > ago(7d)
| project TimeGenerated,
          Action = action_name_s,
          User = database_principal_name_s,
          ClientIP = client_ip_s,
          Table = object_name_s,
          Query = substring(statement_s, 0, 200)
| order by TimeGenerated desc
```

**Usage** : Traçabilité des accès aux données de santé (RGPD Article 9)

#### 4. Security Events Timeline

```kql
union
    (AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where ResultSignature != "OK"
    | project TimeGenerated, EventType = "KeyVault-Failed",
              User = identity_claim_upn_s, Detail = OperationName),
    (AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.SQL"
    | where Category == "SQLSecurityAuditEvents"
    | where succeeded_s == "false"
    | project TimeGenerated, EventType = "SQL-Failed",
              User = database_principal_name_s, Detail = action_name_s)
| where TimeGenerated > ago(7d)
| order by TimeGenerated desc
```

**Usage** : Vue consolidée des événements de sécurité

#### 5. Compliance Daily Summary

```kql
AzureDiagnostics
| where TimeGenerated > ago(1d)
| summarize
    TotalOperations = count(),
    FailedOperations = countif(ResultSignature != "OK"),
    KeyVaultAccess = countif(ResourceProvider == "MICROSOFT.KEYVAULT"),
    SQLAccess = countif(ResourceProvider == "MICROSOFT.SQL"),
    UniqueUsers = dcount(identity_claim_upn_s)
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

**Usage** : Rapport quotidien pour conformité HDS

### Utilisation dans le portail Azure

1. **Azure Portal** → **Log Analytics Workspace**
2. **Logs** → Coller la requête KQL
3. **Run** → Voir les résultats
4. **Export** → CSV, JSON, Excel

### Utilisation via Azure CLI

```bash
# Exécuter une requête KQL
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where TimeGenerated > ago(1d)" \
  --output table
```

---

## 🚨 Alertes Azure Monitor

**Fichier** : `infra/core/monitor/alerts.bicep`

### 8 alertes configurées

| Alerte | Sévérité | Déclencheur | Compliance |
|--------|----------|-------------|------------|
| **Failed Key Vault Access** | High | > 5 échecs/5min | HDS 7.2 |
| **SQL Injection Attempt** | Critical | Patterns suspects | HDS 7.2 |
| **Unauthorized Data Access** | High | > 3 échecs/5min | HDS 7.2 |
| **Mass Data Export** | High | > 100 SELECT/5min | RGPD 9 |
| **Health Check Failure** | High | > 3 échecs/5min | HDS 8.1 |
| **Application Error Spike** | Medium | > 10 errors/min | HDS 8.1 |
| **Secret Expiration** | Warning | < 7 jours | HDS 9.1 |
| **Deployment Failure** | High | Swap échec | HDS 8.1 |

### Configuration d'une alerte

#### Via Bicep

```bicep
resource alertFailedKeyVaultAccess 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-failed-keyvault-access'
  location: location
  properties: {
    displayName: 'Multiple Failed Key Vault Access Attempts'
    description: 'HDS Article 7.2 - Intrusion detection'
    severity: 2  // High
    enabled: true
    evaluationFrequency: 'PT5M'  // Every 5 minutes
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [{
        query: '''
          AzureDiagnostics
          | where ResourceProvider == "MICROSOFT.KEYVAULT"
          | where ResultSignature != "OK"
          | where TimeGenerated > ago(5m)
          | summarize FailedAttempts = count() by CallerIPAddress
          | where FailedAttempts > 5
        '''
        threshold: 0
        operator: 'GreaterThan'
      }]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}
```

#### Via Azure Portal

1. **Azure Monitor** → **Alerts** → **+ New alert rule**
2. **Scope** : Log Analytics Workspace
3. **Condition** : Custom log search
4. **Query** : Coller la requête KQL
5. **Threshold** : > 0
6. **Action Group** : Sélectionner groupe de notifications
7. **Create**

### Action Group (Notifications)

**Fichier** : `infra/core/monitor/actiongroup.bicep`

```bicep
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'SecurityAlerts'
  properties: {
    groupShortName: 'MedSecure'
    emailReceivers: [
      { name: 'SecurityTeam', emailAddress: 'security@medsecure.fr' }
    ]
    smsReceivers: [
      { name: 'OnCall', countryCode: '33', phoneNumber: '0612345678' }
    ]
    webhookReceivers: [
      { name: 'Teams', serviceUri: 'https://webhook.teams...' }
    ]
  }
}
```

---

## 📄 Rapports de conformité

**Script** : `scripts/Generate-ComplianceReport.ps1`

### Génération de rapports

#### Commandes

```powershell
# Rapport quotidien
.\Generate-ComplianceReport.ps1 `
  -WorkspaceId "xxx-xxx-xxx" `
  -ReportType Daily

# Rapport mensuel
.\Generate-ComplianceReport.ps1 `
  -WorkspaceId "xxx-xxx-xxx" `
  -ReportType Monthly

# Rapport personnalisé
.\Generate-ComplianceReport.ps1 `
  -WorkspaceId "xxx-xxx-xxx" `
  -ReportType Custom `
  -StartDate "2024-01-01" `
  -EndDate "2024-01-31" `
  -OutputFormat HTML
```

### Rapports générés

1. **KeyVault-Access-Audit**
   - Tous les accès aux secrets (90 jours)
   - Formats : JSON, HTML, CSV

2. **SQL-Access-Audit**
   - Tous les accès à la base de données
   - Conformité RGPD Article 9

3. **Security-Events-Summary**
   - Résumé quotidien des événements de sécurité
   - Métriques de conformité

4. **Master-Compliance-Report**
   - Rapport consolidé
   - Statut de conformité HDS/RGPD/ISO27001

### Exemple de sortie

```
╔═══════════════════════════════════════════════════════════╗
║   MedSecure - HDS Compliance Report Generator           ║
╚═══════════════════════════════════════════════════════════╝

Report Type: Monthly
Date Range: 2024-01-01 to 2024-01-31
Workspace ID: xxx-xxx-xxx

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. Key Vault Access Audit (HDS Article 4.1)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2024-01-15 14:30:00] Running query: Key Vault Access
[2024-01-15 14:30:05] JSON report saved: ./compliance-reports/KeyVault-Access-Audit-2024-01-15-1430.json
[2024-01-15 14:30:06] HTML report saved: ./compliance-reports/KeyVault-Access-Audit-2024-01-15-1430.html
[2024-01-15 14:30:07] CSV report saved: ./compliance-reports/KeyVault-Access-Audit-2024-01-15-1430.csv

═══════════════════════════════════════════════════════════
 ✅ All Compliance Reports Generated Successfully
═══════════════════════════════════════════════════════════

📁 Reports location: ./compliance-reports

Generated reports:
  - KeyVault-Access-Audit-2024-01-15-1430.json
  - KeyVault-Access-Audit-2024-01-15-1430.html
  - KeyVault-Access-Audit-2024-01-15-1430.csv
  - SQL-Access-Audit-2024-01-15-1430.json
  - SQL-Access-Audit-2024-01-15-1430.html
  - SQL-Access-Audit-2024-01-15-1430.csv
  - Security-Events-Summary-2024-01-15-1430.json
  - Security-Events-Summary-2024-01-15-1430.html
  - Security-Events-Summary-2024-01-15-1430.csv
  - Master-Compliance-Report-2024-01-15-1430.json
```

---

## 🏥 Conformité HDS

### Articles HDS couverts

| Article | Exigence | Implémentation | Preuve |
|---------|----------|----------------|--------|
| **4.1** | Traçabilité des accès | Log Analytics 90j | Requêtes KQL 1-3 ✅ |
| **4.2** | Conservation logs | Retention policy | Bicep configuration ✅ |
| **7.2** | Détection menaces | 15 alertes temps réel | alerts.bicep ✅ |
| **8.1** | Disponibilité | Health check alerts | Alert 5-6 ✅ |
| **9.1** | Gestion secrets | Rotation tracking | Requête KQL 4 ✅ |

**Taux de conformité** : **100%** (5/5 exigences)

### RGPD Article 9 - Données de santé

```kql
// Traçabilité accès aux données de santé
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "SQLSecurityAuditEvents"
| where object_name_s contains "Patient" or object_name_s contains "MedicalRecord"
| where TimeGenerated > ago(30d)
| project TimeGenerated,
          Action = action_name_s,
          User = database_principal_name_s,
          Table = object_name_s,
          ClientIP = client_ip_s
```

**Conservation** : 90 jours minimum (RGPD + HDS)

### Audit trail pour certification

**Fichiers à fournir lors de l'audit HDS** :

1. ✅ Configuration Log Analytics (retention 90j)
2. ✅ Liste des alertes configurées (15 alertes)
3. ✅ Requêtes KQL (16 requêtes documentées)
4. ✅ Rapports mensuels (derniers 3 mois)
5. ✅ Preuves de notifications (emails, SMS)
6. ✅ Documentation complète (ce guide)

---

## 💻 Utilisation

### Accès rapide aux logs

#### Via Azure Portal

1. **Azure Portal** → **Log Analytics Workspace** → **medsecure-logs**
2. **Logs** → Coller une requête KQL
3. **Time range** : Ajuster la période
4. **Run** → Voir les résultats
5. **Export** → Télécharger en CSV/JSON

#### Via Azure CLI

```bash
# Workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-medsecure-prod \
  --workspace-name medsecure-logs \
  --query customerId -o tsv)

# Exécuter requête
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureDiagnostics | where TimeGenerated > ago(1d) | take 10" \
  --output table
```

### Vérification quotidienne

**Checklist quotidienne** :

```powershell
# 1. Vérifier les alertes déclenchées
az monitor alert list \
  --resource-group rg-medsecure-prod \
  --query "[?properties.enabled==true && properties.condition.allOf[0].timeAggregation=='Count']"

# 2. Générer rapport quotidien
.\scripts\Generate-ComplianceReport.ps1 `
  -WorkspaceId $WORKSPACE_ID `
  -ReportType Daily

# 3. Vérifier les événements de sécurité
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "
    AzureDiagnostics
    | where TimeGenerated > ago(1d)
    | where ResultSignature != 'OK' or succeeded_s == 'false'
    | summarize count() by ResourceProvider
  "
```

### Alertes critiques

**Procédure en cas d'alerte** :

1. **Notification reçue** (Email/SMS/Teams)
2. **Identifier la source** : Requête KQL dans l'email
3. **Investiguer** :
   ```kql
   AzureDiagnostics
   | where CallerIPAddress == "<IP détectée>"
   | where TimeGenerated > ago(1h)
   | project TimeGenerated, OperationName, ResultSignature
   ```
4. **Actions** :
   - Si attaque : Bloquer IP (Firewall règles)
   - Si faux positif : Ajuster la requête d'alerte
   - Si comportement suspect : Escalade Security Team
5. **Documentation** : Créer incident dans Azure DevOps

---

## 📚 Ressources

### Documentation officielle

- **KQL Language** : https://learn.microsoft.com/azure/data-explorer/kusto/query/
- **Azure Monitor Alerts** : https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview
- **Log Analytics** : https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview

### Fichiers

- `monitoring/kql-queries/hds-audit-trail.kql` - 16 requêtes HDS
- `monitoring/kql-queries/security-alerts.kql` - 15 requêtes d'alerte
- `infra/core/monitor/alerts.bicep` - Configuration alertes
- `infra/core/monitor/actiongroup.bicep` - Notifications
- `scripts/Generate-ComplianceReport.ps1` - Génération rapports

### Guides associés

- [HDS Compliance Audit](./HDS_COMPLIANCE_AUDIT.md)
- [Key Vault Audit Guide](./KEY_VAULT_AUDIT_GUIDE.md)
- [DevSecOps Guide](./DEVSECOPS_GUIDE.md)

---

## ✅ Checklist de conformité

### Quotidienne
- [ ] Vérifier les alertes déclenchées
- [ ] Générer rapport quotidien
- [ ] Vérifier les événements de sécurité

### Hebdomadaire
- [ ] Générer rapport hebdomadaire
- [ ] Review des alertes (faux positifs?)
- [ ] Vérifier retention policy (90 jours)

### Mensuelle
- [ ] Générer rapport mensuel complet
- [ ] Archiver les rapports (PDF)
- [ ] Review avec Security Team
- [ ] Mise à jour documentation si nécessaire

### Annuelle (Audit HDS)
- [ ] Rapports 12 derniers mois
- [ ] Preuves de retention 90 jours
- [ ] Liste alertes + déclenchements
- [ ] Documentation à jour
- [ ] Procédures testées et validées

---

**Version** : 1.0.0
**Dernière mise à jour** : 2024-01-15
**Auteur** : MedSecure DevOps Team
