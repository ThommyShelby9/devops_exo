# Guide de Rotation des Secrets Key Vault - MedSecure

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture de rotation](#architecture-de-rotation)
3. [Configuration](#configuration)
4. [Rotation automatique](#rotation-automatique)
5. [Rotation manuelle](#rotation-manuelle)
6. [Pipeline de vérification](#pipeline-de-vérification)
7. [Conformité HDS](#conformité-hds)
8. [Dépannage](#dépannage)

---

## 🎯 Vue d'ensemble

### Pourquoi la rotation des secrets ?

La rotation régulière des secrets est une **exigence de sécurité critique** pour :

| Raison | Impact |
|--------|--------|
| 🔐 **Sécurité** | Limite la fenêtre d'exposition en cas de compromission |
| 🏥 **HDS Compliance** | Obligatoire pour la certification HDS |
| 📜 **RGPD Article 32** | Mesures techniques pour assurer la sécurité des données |
| 🛡️ **ISO 27001** | Contrôle A.9.3.1 - Gestion des mots de passe |
| ⏰ **Détection de brèche** | Invalide les credentials compromis |

### Stratégie de rotation

```
┌─────────────────────────────────────────────────────────────┐
│  Secret Lifecycle                                           │
└─────────────────────────────────────────────────────────────┘

Day 0          Day 30         Day 60         Day 90
  │              │              │              │
  ▼              ▼              ▼              ▼
Created    Notification   Notification    Expiration
           (60 days)      (30 days)       (Rotate!)
  │              │              │              │
  └──────────────┴──────────────┴──────────────┘
         Valid Period (90 days)
```

**Paramètres par défaut** :
- ✅ **Validity Period** : 90 jours
- ✅ **Notification Threshold** : 30 jours avant expiration
- ✅ **Auto-rotation** : Activée pour DEV, manuelle pour STAGING/PROD

---

## 🏗️ Architecture de rotation

### Composants

```
┌─────────────────────────────────────────────────────────────┐
│  1. AZURE KEY VAULT                                         │
│  - Secrets with expiration dates                           │
│  - Event Grid integration                                  │
│  - Audit logging (90 days)                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  2. EVENT GRID TOPIC                                        │
│  - SecretNearExpiry event                                  │
│  - SecretExpired event                                     │
│  - SecretNewVersionCreated event                           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  3. AZURE PIPELINES (Scheduled)                             │
│  - Daily check (9 AM UTC)                                  │
│  - Automatic rotation (DEV)                                │
│  - Manual approval (STAGING/PROD)                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  4. POWERSHELL SCRIPT                                       │
│  - Generate secure passwords                               │
│  - Update Key Vault secrets                                │
│  - Update dependent systems (SQL, App Service, etc.)       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  5. NOTIFICATIONS                                           │
│  - Work Items (Azure DevOps)                               │
│  - Email alerts                                            │
│  - Audit trail (HDS compliance)                            │
└─────────────────────────────────────────────────────────────┘
```

### Types de secrets gérés

| Secret Type | Length | Complexity | Auto-Rotate | Update Target |
|-------------|--------|------------|-------------|---------------|
| **SQL Admin Password** | 32 | High | ✅ | Azure SQL Server |
| **App Secret** (OAuth/JWT) | 64 | High | ✅ | App Service Settings |
| **Storage Account Key** | 88 | Azure Key | ✅ | Storage Account |
| **Service Bus Connection** | N/A | Azure | ✅ | Service Bus |

---

## ⚙️ Configuration

### 1. Infrastructure Bicep

**Fichier** : `infra/core/security/keyvault.bicep`

```bicep
@description('Enable secret rotation policies')
param enableSecretRotation bool = true

@description('Secret rotation notification days before expiry')
param rotationNotificationDays int = 30

@description('Default secret validity period in days')
param secretValidityDays int = 90

// Event Grid subscription for notifications
resource keyVaultEventSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  name: '${name}-secret-expiration'
  scope: keyVault
  properties: {
    destination: {
      endpointType: 'EventGrid'
      properties: {
        resourceId: eventGridTopicId
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.KeyVault.SecretNearExpiry'
        'Microsoft.KeyVault.SecretExpired'
        'Microsoft.KeyVault.SecretNewVersionCreated'
      ]
    }
  }
}
```

### 2. Secrets avec expiration

Les secrets sont créés avec une date d'expiration :

```bicep
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'SqlAdminPassword'
  parent: keyVault
  properties: {
    value: 'PLACEHOLDER'  // Will be set via pipeline
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(utcNow(), 'P90D'))  // Expires in 90 days
      nbf: dateTimeToEpoch(utcNow())
    }
  }
  tags: {
    'RotationPolicy': 'Automatic'
    'ValidityDays': '90'
    'NotificationDays': '30'
  }
}
```

### 3. Pipeline de vérification quotidien

**Fichier** : `pipelines/secret-rotation-check.yml`

```yaml
schedules:
  - cron: "0 9 * * *"  # Daily at 9 AM UTC
    displayName: 'Daily Secret Expiration Check'
    branches:
      include:
        - main
    always: true

variables:
  keyVaultDev: 'kv-medsecure-dev'
  keyVaultStaging: 'kv-medsecure-staging'
  keyVaultProd: 'kv-medsecure-prod'
  rotationThresholdDays: 30
  validityDays: 90
```

---

## 🔄 Rotation automatique

### Pipeline quotidien

Le pipeline s'exécute tous les jours à 9h UTC pour :

1. ✅ **DEV** : Rotation automatique (pas d'approbation)
2. ⚠️ **STAGING** : Vérification + Work Item (approbation manuelle)
3. ⚠️ **PRODUCTION** : Vérification + Work Item (double approbation)

### Workflow automatique (DEV)

```
09:00 UTC - Pipeline démarre
   ↓
Vérifier secrets dans kv-medsecure-dev
   ↓
Secrets expirant dans < 30 jours?
   ↓
   OUI → Rotation automatique
   │     ├─ Générer nouveau secret
   │     ├─ Mettre à jour Key Vault
   │     ├─ Mettre à jour système cible (SQL, App Service)
   │     └─ Créer audit trail
   ↓
   NON → Aucune action
   ↓
Générer rapport
```

### Exemple de rapport

```json
{
  "timestamp": "2024-01-15T09:00:00Z",
  "keyVault": "kv-medsecure-dev",
  "checkOnly": false,
  "expiringSecretsCount": 2,
  "rotatedSecrets": [
    {
      "name": "SqlAdminPassword",
      "oldExpiry": "2024-01-20",
      "newExpiry": "2024-04-15",
      "rotationStatus": "Success"
    },
    {
      "name": "AppSecret",
      "oldExpiry": "2024-01-25",
      "newExpiry": "2024-04-20",
      "rotationStatus": "Success"
    }
  ]
}
```

---

## 🔧 Rotation manuelle

### Script PowerShell

**Fichier** : `scripts/Rotate-KeyVaultSecrets.ps1`

#### Commandes de base

```powershell
# 1. Vérifier l'état des secrets
.\Rotate-KeyVaultSecrets.ps1 `
  -KeyVaultName "kv-medsecure-prod" `
  -WhatIf

# 2. Rotater un secret spécifique
.\Rotate-KeyVaultSecrets.ps1 `
  -KeyVaultName "kv-medsecure-prod" `
  -SecretName "SqlAdminPassword"

# 3. Rotater tous les secrets (avec confirmation)
.\Rotate-KeyVaultSecrets.ps1 `
  -KeyVaultName "kv-medsecure-prod"

# 4. Rotater tous les secrets (sans confirmation)
.\Rotate-KeyVaultSecrets.ps1 `
  -KeyVaultName "kv-medsecure-prod" `
  -Force
```

#### Paramètres avancés

```powershell
.\Rotate-KeyVaultSecrets.ps1 `
  -KeyVaultName "kv-medsecure-prod" `
  -SecretName "SqlAdminPassword" `
  -ValidityDays 180 `            # Nouvelle expiration dans 180 jours
  -NotificationDays 60 `         # Notification 60 jours avant
  -Force                          # Pas de confirmation
```

### Workflow manuel

#### Étape 1 : Vérifier les secrets expirant

```powershell
PS> .\Rotate-KeyVaultSecrets.ps1 -KeyVaultName "kv-medsecure-prod" -WhatIf

╔═══════════════════════════════════════════════════════════╗
║   MedSecure - Key Vault Secret Rotation                 ║
║   Automated Secret Management                            ║
╚═══════════════════════════════════════════════════════════╝

⚠️  Running in WhatIf mode - no changes will be made

[2024-01-15 14:30:00] ℹ️  Key Vault: kv-medsecure-prod
[2024-01-15 14:30:00] ℹ️  Validity Period: 90 days
[2024-01-15 14:30:00] ℹ️  Notification Period: 30 days

═══════════════════════════════════════════════════════════
 ⚠️  Secrets Near Expiry
═══════════════════════════════════════════════════════════

Status           Name                DaysUntilExpiry ExpiryDate
------           ----                --------------- ----------
🔴 CRITICAL      SqlAdminPassword    5               2024-01-20
🟡 WARNING       AppSecret           25              2024-02-09
🟢 OK            StorageAccountKey   60              2024-03-15
```

#### Étape 2 : Rotater les secrets critiques

```powershell
PS> .\Rotate-KeyVaultSecrets.ps1 `
      -KeyVaultName "kv-medsecure-prod" `
      -SecretName "SqlAdminPassword"

═══════════════════════════════════════════════════════════
 🔄 Rotating Secret: SqlAdminPassword
═══════════════════════════════════════════════════════════

[2024-01-15 14:35:00] ℹ️  Current expiration: 5 days

⚠️  WARNING: You are about to rotate secret 'SqlAdminPassword'

Secret Type: Password
Validity: 90 days
Update Target: AzureSQL

Type 'ROTATE' to confirm: ROTATE

[2024-01-15 14:35:10] ℹ️  Rotating secret: SqlAdminPassword
[2024-01-15 14:35:12] ✅ Secret 'SqlAdminPassword' rotated successfully (expires: 2024-04-15)
[2024-01-15 14:35:12] ℹ️  Updating target system: AzureSQL

✅ Secret 'SqlAdminPassword' rotated successfully!
```

#### Étape 3 : Vérifier la rotation

```powershell
# Vérifier dans Azure CLI
az keyvault secret show \
  --vault-name kv-medsecure-prod \
  --name SqlAdminPassword \
  --query "attributes.expires" \
  --output tsv

# Expected: 2024-04-15T14:35:12Z
```

---

## 📅 Pipeline de vérification

### Configuration du pipeline planifié

**Fichier** : `pipelines/secret-rotation-check.yml`

#### Stages

1. **CheckDev** : Vérifier et rotater automatiquement (DEV)
2. **CheckStaging** : Vérifier et créer Work Item (STAGING)
3. **CheckProduction** : Vérifier et créer Work Item (PROD)
4. **RotateStaging** : Rotation manuelle après approbation (STAGING)
5. **RotateProduction** : Rotation manuelle après double approbation (PROD)
6. **Summary** : Génération du rapport

#### Environnements Azure DevOps

Créer les environments suivants :

##### keyvault-rotation-staging
- **Approbations** : 1 personne (Security Team)
- **Checks** : Build succeeded

##### keyvault-rotation-production
- **Approbations** : 2 personnes (Security Team + Infrastructure Lead)
- **Checks** : Build succeeded, STAGING rotated
- **Business hours** : Rotation uniquement 9h-17h (optionnel)

### Exécution manuelle

```bash
# Déclencher le pipeline manuellement
az pipelines run \
  --name "Secret Rotation Check" \
  --org https://dev.azure.com/medsecure \
  --project MedSecure
```

### Notifications

#### Work Items automatiques

Lorsque des secrets expirent bientôt, un Work Item est créé automatiquement :

```
Title: ⚠️ Key Vault secrets expiring soon in kv-medsecure-prod

Description:
Found 2 secret(s) expiring within 30 days in Key Vault: kv-medsecure-prod

Secrets:
- SqlAdminPassword (expires in 5 days)
- AppSecret (expires in 25 days)

Please rotate these secrets using:
1. Run: ./scripts/Rotate-KeyVaultSecrets.ps1 -KeyVaultName kv-medsecure-prod
   OR
2. Re-run pipeline with checkOnly=false

Build: 1.0.25
Build URL: https://dev.azure.com/medsecure/...
```

#### Email (configuration requise)

Configurer dans **Azure DevOps** → **Project Settings** → **Notifications** :

1. **Nouveau subscription**
2. **Category** : Build
3. **Template** : A build completes
4. **Filters** :
   - Pipeline = "Secret Rotation Check"
   - Status = Succeeded with issues
5. **Delivery** : Email to Security Team

---

## 🏥 Conformité HDS

### Exigences HDS couvertes

| Article HDS | Exigence | Implémentation | Statut |
|-------------|----------|----------------|--------|
| **9.1** | Gestion des mots de passe | Rotation automatique | ✅ |
| **9.2** | Complexité des mots de passe | 32+ chars, high complexity | ✅ |
| **9.3** | Durée de validité limitée | Max 90 jours | ✅ |
| **9.4** | Stockage sécurisé | Azure Key Vault (HSM) | ✅ |
| **4.1** | Traçabilité | Audit trail complet | ✅ |
| **4.2** | Conservation des logs | 90 jours | ✅ |

**Taux de conformité** : **100%** (6/6 exigences)

### Audit trail

Chaque rotation génère un audit trail :

**Fichier** : `logs/secret-rotation-YYYY-MM-DD.json`

```json
{
  "Timestamp": "2024-01-15 14:35:00",
  "Level": "Info",
  "Message": "Rotating secret: SqlAdminPassword",
  "KeyVault": "kv-medsecure-prod",
  "SecretName": "SqlAdminPassword",
  "User": "john.doe",
  "Machine": "DESKTOP-ABC123"
}
```

**Pipeline artifact** : `KeyVault-Rotation-Reports/rotation-audit.json`

```json
{
  "timestamp": "2024-01-15T14:35:00Z",
  "action": "SecretRotationCheck",
  "keyVault": "kv-medsecure-prod",
  "checkOnly": false,
  "rotationThresholdDays": 30,
  "validityDays": 90,
  "expiringSecretsCount": 2,
  "buildId": "12345",
  "triggeredBy": "john.doe@medsecure.fr",
  "compliance": {
    "hds": true,
    "rgpd": true,
    "iso27001": true
  }
}
```

### Conservation des logs

- **Audit trail PowerShell** : 90 jours (local)
- **Pipeline artifacts** : 90 jours (Azure DevOps)
- **Key Vault logs** : 90 jours (Log Analytics)
- **Event Grid events** : 24 heures (retry policy)

---

## 🛠️ Dépannage

### Problème : Secret rotation échoue avec "Access denied"

**Symptôme** :
```
Error: The user, group or application does not have secrets set permission
```

**Causes** :
1. Managed Identity n'a pas les permissions
2. Access Policy incorrecte

**Solution** :
```bash
# 1. Vérifier les permissions
az keyvault show \
  --name kv-medsecure-prod \
  --query "properties.accessPolicies"

# 2. Ajouter les permissions
az keyvault set-policy \
  --name kv-medsecure-prod \
  --object-id <managed-identity-id> \
  --secret-permissions get list set delete
```

---

### Problème : SQL Server password update échoue

**Symptôme** :
```
Error: Failed to update SQL Server password
```

**Causes** :
1. Firewall règles bloquent l'accès
2. Nom du serveur SQL incorrect

**Solution** :
```powershell
# 1. Configurer le script avec les bons paramètres
$RotationConfig = @{
    'SqlAdminPassword' = @{
        Type = 'Password'
        Length = 32
        Complexity = 'High'
        UpdateTarget = 'AzureSQL'
        ServerName = 'sql-medsecure-prod'          # ← Ajouter
        ResourceGroup = 'rg-medsecure-prod'        # ← Ajouter
    }
}

# 2. Ajouter firewall rule pour l'agent
az sql server firewall-rule create \
  --resource-group rg-medsecure-prod \
  --server sql-medsecure-prod \
  --name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

---

### Problème : Pipeline scheduled ne démarre pas

**Symptôme** :
```
Pipeline scheduled but not running at expected time
```

**Causes** :
1. Branch `main` n'a pas de changements récents
2. Scheduled trigger pas activé

**Solution** :
```yaml
# 1. Vérifier la configuration du schedule
schedules:
  - cron: "0 9 * * *"
    displayName: 'Daily Secret Expiration Check'
    branches:
      include:
        - main
    always: true  # ← IMPORTANT: Run even without code changes
```

---

### Problème : Notification email non reçue

**Symptôme** :
```
Secrets expiring but no email received
```

**Causes** :
1. Notification Azure DevOps pas configurée
2. Work Item créé mais pas d'email

**Solution** :

**Option 1 : Configurer Azure DevOps Notifications**
1. **Project Settings** → **Notifications**
2. **New subscription**
3. Template : "A build completes"
4. Filters : Pipeline = "Secret Rotation Check"
5. Delivery : Email to team/individual

**Option 2 : Utiliser Azure Monitor Action Group**
```bash
# Créer Action Group
az monitor action-group create \
  --name "KeyVaultRotationAlerts" \
  --resource-group rg-medsecure-prod \
  --short-name "KVRotation" \
  --email-receiver name="SecurityTeam" email="security@medsecure.fr"

# Créer Alert Rule
az monitor metrics alert create \
  --name "SecretExpiring" \
  --resource-group rg-medsecure-prod \
  --scopes /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/kv-medsecure-prod \
  --condition "count SecretNearExpiry > 0" \
  --action /subscriptions/.../resourceGroups/.../providers/Microsoft.Insights/actionGroups/KeyVaultRotationAlerts
```

---

## 📚 Ressources

### Documentation officielle

- **Azure Key Vault Rotation** : https://learn.microsoft.com/azure/key-vault/secrets/tutorial-rotation
- **Event Grid Integration** : https://learn.microsoft.com/azure/key-vault/general/event-grid-overview
- **Azure Pipelines Scheduled Triggers** : https://learn.microsoft.com/azure/devops/pipelines/process/scheduled-triggers

### Scripts et templates

- `infra/core/security/keyvault.bicep` - Infrastructure Key Vault
- `infra/core/messaging/eventgrid-topic.bicep` - Event Grid Topic
- `scripts/Rotate-KeyVaultSecrets.ps1` - Script de rotation manuel
- `pipelines/templates/security/keyvault-rotation.yml` - Template pipeline
- `pipelines/secret-rotation-check.yml` - Pipeline planifié

### Guides associés

- [HDS Compliance Audit](./HDS_COMPLIANCE_AUDIT.md)
- [DevSecOps Guide](./DEVSECOPS_GUIDE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Key Vault Audit Guide](./KEY_VAULT_AUDIT_GUIDE.md)

---

## ✅ Checklist de rotation

### Avant la rotation

- [ ] Vérifier les secrets expirant (`-WhatIf`)
- [ ] Identifier les systèmes dépendants (SQL, App Service, etc.)
- [ ] Planifier une fenêtre de maintenance (si nécessaire)
- [ ] Informer l'équipe
- [ ] Backup de la configuration actuelle

### Pendant la rotation

- [ ] Exécuter le script de rotation
- [ ] Vérifier que le nouveau secret est créé
- [ ] Vérifier que les systèmes dépendants sont mis à jour
- [ ] Tester la connectivité avec le nouveau secret
- [ ] Vérifier les logs (aucune erreur)

### Après la rotation

- [ ] Vérifier que l'application fonctionne normalement
- [ ] Tester les fonctionnalités critiques
- [ ] Vérifier l'audit trail
- [ ] Documenter la rotation (date, qui, quoi)
- [ ] Archiver l'ancien secret (si nécessaire)
- [ ] Mettre à jour la documentation des secrets

---

**Version** : 1.0.0
**Dernière mise à jour** : 2024-01-15
**Auteur** : MedSecure DevOps Team
