# Guide de Déploiement Blue/Green - MedSecure

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture Blue/Green](#architecture-blue-green)
3. [Configuration](#configuration)
4. [Processus de déploiement](#processus-de-déploiement)
5. [Smoke Tests](#smoke-tests)
6. [Rollback](#rollback)
7. [Gestion manuelle](#gestion-manuelle)
8. [Conformité HDS](#conformité-hds)
9. [Dépannage](#dépannage)

---

## 🎯 Vue d'ensemble

### Qu'est-ce que Blue/Green Deployment ?

Le **déploiement Blue/Green** est une stratégie de déploiement qui réduit les temps d'arrêt et les risques en maintenant deux environnements de production identiques :

- **🔵 Blue (Production)** : Environnement actuellement en service, recevant le trafic utilisateur
- **🟢 Green (Staging)** : Environnement de préproduction pour tester la nouvelle version

### Avantages

| Avantage | Description |
|----------|-------------|
| ⚡ **Zéro downtime** | Swap instantané entre les slots |
| 🔄 **Rollback rapide** | Retour arrière en quelques secondes |
| ✅ **Validation production** | Tests sur un environnement identique à la prod |
| 🏥 **Conformité HDS** | Traçabilité complète des déploiements |

### Azure App Service Slots

Azure App Service implémente Blue/Green via les **deployment slots** :

```
Production Slot (Blue)         Staging Slot (Green)
┌──────────────────┐           ┌──────────────────┐
│   Version 1.0.0  │           │   Version 1.0.1  │
│   100% Traffic   │           │   0% Traffic     │
└──────────────────┘           └──────────────────┘
         │                              │
         └─────────── SWAP ─────────────┘
                       ↓
┌──────────────────┐           ┌──────────────────┐
│   Version 1.0.1  │           │   Version 1.0.0  │
│   100% Traffic   │           │   0% Traffic     │
└──────────────────┘           └──────────────────┘
Production Slot (Blue)         Staging Slot (Green)
```

---

## 🏗️ Architecture Blue/Green

### Flux de déploiement

```
┌─────────────────────────────────────────────────────────────┐
│  1. BUILD                                                   │
│  - Compiler le code                                         │
│  - Exécuter les tests unitaires                             │
│  - Créer l'artefact (ZIP)                                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  2. SECURITY SCANNING                                       │
│  - SonarCloud (SAST)                                        │
│  - Gitleaks (Secrets)                                       │
│  - Snyk/OWASP (SCA)                                         │
│  - Trivy (Container)                                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  3. DEPLOY TO STAGING SLOT (Green)                          │
│  - Déployer vers le slot "staging"                          │
│  - Warm-up de l'application                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  4. SMOKE TESTS                                             │
│  - Health check endpoint                                    │
│  - Response time validation                                 │
│  - SSL/TLS certificate check                                │
│  - Security headers validation                              │
│  - Performance metrics                                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    Tests PASSED?
                     /          \
                   YES           NO
                    ↓             ↓
         ┌──────────────────┐   ❌ ABORT
         │  5. SWAP PREVIEW │
         │  (Optional)      │
         └──────────────────┘
                    ↓
         ┌──────────────────┐
         │  6. MANUAL       │
         │  APPROVAL        │
         │  (STAGING/PROD)  │
         └──────────────────┘
                    ↓
         ┌──────────────────┐
         │  7. COMPLETE     │
         │  SWAP            │
         │  Green → Blue    │
         └──────────────────┘
                    ↓
         ┌──────────────────┐
         │  8. POST-SWAP    │
         │  VALIDATION      │
         └──────────────────┘
                    ↓
              Validation OK?
               /          \
             YES           NO
              ↓             ↓
         ✅ SUCCESS    🔄 ROLLBACK
```

### Environnements et stratégies

| Environnement | Auto-Swap | Swap Preview | Manual Approval | Rollback |
|---------------|-----------|--------------|-----------------|----------|
| **DEV** | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| **STAGING** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **PRODUCTION** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |

---

## ⚙️ Configuration

### 1. Infrastructure Bicep

Le slot de staging est défini dans `infra/core/host/appservice.bicep` :

```bicep
@description('Enable deployment slots for Blue/Green deployment')
param enableDeploymentSlots bool = true

@description('Name of the staging slot')
param stagingSlotName string = 'staging'

resource appServiceSlotStaging 'Microsoft.Web/sites/slots@2022-03-01' = if (enableDeploymentSlots) {
  name: stagingSlotName
  parent: appService
  location: location
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      healthCheckPath: healthCheckPath
      autoSwapSlotName: ''  // Empty = manual swap only
    }
  }
}
```

**Important** :
- `enableDeploymentSlots: true` - Active les slots
- `autoSwapSlotName: ''` - Désactive le swap automatique (conformité HDS)
- `healthCheckPath` - Endpoint de santé pour validation

### 2. Variables Azure DevOps

Les variables suivantes doivent être définies dans Azure DevOps :

```yaml
# Variable Group: MedSecure-Infrastructure

# DEV Environment
RESOURCE_GROUP_DEV: 'rg-medsecure-dev'
APP_SERVICE_NAME_DEV: 'app-medsecure-dev'

# STAGING Environment
RESOURCE_GROUP_STAGING: 'rg-medsecure-staging'
APP_SERVICE_NAME_STAGING: 'app-medsecure-staging'

# PRODUCTION Environment
RESOURCE_GROUP_PROD: 'rg-medsecure-prod'
APP_SERVICE_NAME_PROD: 'app-medsecure-prod'

# Azure Connection
AZURE_SERVICE_CONNECTION: 'Azure-MedSecure'  # Service Connection name
```

### 3. Azure DevOps Environments

Créer les environments avec approbations manuelles :

#### Environment: medsecure-dev
- **Approbations** : Aucune
- **Auto-deploy** : Oui (branche `develop`)

#### Environment: medsecure-staging
- **Approbations** : Security Team (1 personne)
- **Auto-deploy** : Non (branche `main`)
- **Checks** : Build succeeded, Security scans passed

#### Environment: medsecure-production
- **Approbations** : Security Team + Tech Lead (2 personnes)
- **Auto-deploy** : Non (après staging)
- **Checks** : Build succeeded, Security scans passed, Staging deployed
- **Business hours** : Déploiements uniquement 9h-17h (optionnel)

---

## 🚀 Processus de déploiement

### Déploiement automatique (DEV)

**Trigger** : Push vers `develop`

```yaml
# azure-pipelines.yml
- stage: DeployDev
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/develop')
  jobs:
    - deployment: DeployDevEnvironment
      environment: 'medsecure-dev'
      steps:
        - template: pipelines/templates/deployment/blue-green-deploy.yml
          parameters:
            azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
            resourceGroupName: '$(RESOURCE_GROUP_DEV)'
            appServiceName: '$(APP_SERVICE_NAME_DEV)'
            enableAutoSwap: true  # Auto-swap for DEV
            swapWithPreview: false  # Direct swap
            rollbackOnFailure: true
```

**Flux** :
1. Code pushed vers `develop`
2. Build + Tests + Security scans
3. Deploy vers DEV staging slot
4. Smoke tests
5. **Auto-swap** vers production
6. Post-swap validation
7. ✅ Déploiement terminé (ou 🔄 rollback si échec)

---

### Déploiement avec approbation (STAGING)

**Trigger** : Push vers `main`

```yaml
- stage: DeployStaging
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
  jobs:
    - deployment: DeployStagingEnvironment
      environment: 'medsecure-staging'  # Manual approval
      steps:
        - template: pipelines/templates/deployment/blue-green-deploy.yml
          parameters:
            azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
            resourceGroupName: '$(RESOURCE_GROUP_STAGING)'
            appServiceName: '$(APP_SERVICE_NAME_STAGING)'
            enableAutoSwap: false  # Manual approval required
            swapWithPreview: true  # Use swap with preview
            rollbackOnFailure: true
```

**Flux** :
1. Code merged vers `main`
2. Build + Tests + Security scans
3. Deploy vers STAGING staging slot
4. Smoke tests
5. **Swap with preview** (validation en cours)
6. ⏸️  **PAUSE - Approbation manuelle requise**
7. Approbateur valide le déploiement
8. Complete swap vers production
9. Post-swap validation
10. ✅ Déploiement terminé (ou 🔄 rollback si échec)

---

### Déploiement production (PROD)

**Trigger** : Après STAGING réussi

```yaml
- stage: DeployProduction
  dependsOn: DeployStaging
  jobs:
    - deployment: DeployProductionEnvironment
      environment: 'medsecure-production'  # Manual approval (2 approvers)
      steps:
        - template: pipelines/templates/deployment/blue-green-deploy.yml
          parameters:
            azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
            resourceGroupName: '$(RESOURCE_GROUP_PROD)'
            appServiceName: '$(APP_SERVICE_NAME_PROD)'
            enableAutoSwap: false  # Manual approval (HDS compliance)
            swapWithPreview: true  # Maximum safety
            rollbackOnFailure: true
            smokeTestTimeout: 300  # 5 minutes
```

**Flux** :
1. STAGING déployé avec succès
2. Deploy vers PROD staging slot
3. Smoke tests (5 min timeout)
4. **Swap with preview**
5. ⏸️  **PAUSE - Double approbation requise**
6. 2 approbateurs valident (Security + Tech Lead)
7. Complete swap vers production
8. Post-swap validation extensive
9. ✅ Déploiement terminé (ou 🔄 rollback si échec)

---

## 🧪 Smoke Tests

Les smoke tests sont exécutés automatiquement à chaque déploiement.

### Tests inclus

#### 1. Health Check Endpoint

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://app-medsecure-staging.azurewebsites.net/health

# Expected: 200 OK
```

**Critères** :
- ✅ HTTP 200
- ✅ Response time < 2s
- ✅ 5 tentatives avec retry (10s entre chaque)

#### 2. Response Time Validation

```bash
# 10 requêtes pour mesurer la performance
for i in {1..10}; do
  curl -s -o /dev/null -w "%{time_total}\n" \
    https://app-medsecure-staging.azurewebsites.net/health
done
```

**Critères** :
- ✅ Temps moyen < 2.0s
- ⚠️  Alerte si > 2.0s (non bloquant)

#### 3. SSL/TLS Certificate

```bash
echo | openssl s_client -servername app-medsecure.azurewebsites.net \
  -connect app-medsecure.azurewebsites.net:443 2>/dev/null | \
  openssl x509 -noout -dates -subject -issuer
```

**Critères HDS** :
- ✅ TLS 1.3 (recommandé)
- ✅ TLS 1.2 minimum (obligatoire HDS)
- ❌ TLS 1.1 ou inférieur (bloquant)

#### 4. Security Headers

```bash
curl -I https://app-medsecure.azurewebsites.net/health
```

**Headers vérifiés** :
- `Strict-Transport-Security` (HSTS)
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY/SAMEORIGIN`
- `Content-Security-Policy`
- `X-XSS-Protection`

#### 5. Performance Metrics

```bash
curl -w "\nDNS Lookup: %{time_namelookup}s\n\
TCP Connection: %{time_connect}s\n\
TLS Handshake: %{time_appconnect}s\n\
Total Time: %{time_total}s\n" \
  -s -o /dev/null \
  https://app-medsecure.azurewebsites.net/health
```

### Rapports de tests

Les résultats sont publiés dans Azure DevOps :

```
Build Artifacts
└── SmokeTestReports/
    └── smoke-test-report.json
```

**Format JSON** :
```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "targetUrl": "https://app-medsecure-staging.azurewebsites.net",
  "healthCheckPath": "/health",
  "testsPassed": true,
  "buildId": "12345",
  "tests": {
    "healthCheck": "PASSED",
    "responseTime": "PASSED",
    "sslCertificate": "PASSED",
    "securityHeaders": "CHECKED",
    "performanceMetrics": "COLLECTED"
  }
}
```

---

## 🔄 Rollback

### Rollback automatique

Le rollback automatique est activé par défaut si :
- ❌ Smoke tests échouent après le swap
- ❌ Health check retourne HTTP 500+
- ❌ Post-swap validation échoue

**Processus** :
1. Détection de l'échec
2. Swap immédiat : Production ↔ Staging
3. Production revient à la version précédente
4. Notification d'échec
5. Logs et artefacts sauvegardés

### Rollback manuel (Azure Portal)

#### Option 1 : Via Azure Portal

1. **Azure Portal** → **App Services** → Sélectionner l'App Service
2. **Deployment slots** → **Swap**
3. Source : `production`
4. Target : `staging`
5. **Swap**

⚠️  Attention : Cette action n'a pas de confirmation !

#### Option 2 : Via PowerShell Script

```powershell
# Rollback PRODUCTION
.\scripts\Manage-DeploymentSlots.ps1 `
  -Action Rollback `
  -Environment PROD

# Vérifier le statut
.\scripts\Manage-DeploymentSlots.ps1 `
  -Action Status `
  -Environment PROD
```

**Avec confirmation** :
```powershell
PS> .\scripts\Manage-DeploymentSlots.ps1 -Action Rollback -Environment PROD

⚠️  WARNING: You are about to swap deployment slots!

Environment: PROD
Source Slot: production
Target Slot: staging

Type 'ROLLBACK' to confirm: ROLLBACK

🔄 Rollback completed. Production reverted to previous version.
```

#### Option 3 : Via Azure CLI

```bash
# Rollback immédiat
az webapp deployment slot swap \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod \
  --slot staging \
  --target-slot production

# Vérifier la santé
curl https://app-medsecure-prod.azurewebsites.net/health
```

### Temps de rollback

| Méthode | Temps estimé | Downtime |
|---------|--------------|----------|
| **Automatique** | < 30 secondes | ~5 secondes |
| **Manuel (Portal)** | 1-2 minutes | ~10 secondes |
| **Manuel (Script)** | 30 secondes | ~5 secondes |
| **Manuel (CLI)** | 30 secondes | ~5 secondes |

---

## 🔧 Gestion manuelle

### Script PowerShell : Manage-DeploymentSlots.ps1

**Emplacement** : `scripts/Manage-DeploymentSlots.ps1`

#### Commandes disponibles

```powershell
# 1. Voir le statut des slots
.\Manage-DeploymentSlots.ps1 -Action Status -Environment PROD

# 2. Swap direct (sans preview)
.\Manage-DeploymentSlots.ps1 -Action Swap -Environment STAGING

# 3. Swap avec preview
.\Manage-DeploymentSlots.ps1 -Action SwapWithPreview -Environment PROD

# 4. Compléter le swap preview
.\Manage-DeploymentSlots.ps1 -Action CompleteSwap -Environment PROD

# 5. Annuler le swap preview
.\Manage-DeploymentSlots.ps1 -Action CancelSwap -Environment PROD

# 6. Rollback
.\Manage-DeploymentSlots.ps1 -Action Rollback -Environment PROD

# 7. Historique des déploiements
.\Manage-DeploymentSlots.ps1 -Action History -Environment PROD
```

#### Force mode (sans confirmation)

```powershell
# ATTENTION : Skip les confirmations
.\Manage-DeploymentSlots.ps1 `
  -Action Swap `
  -Environment PROD `
  -Force
```

### Audit trail

Toutes les actions sont loggées dans `logs/deployment-YYYY-MM-DD.json` :

```json
{
  "Timestamp": "2024-01-15 14:30:00",
  "Level": "Info",
  "Message": "Initiating slot swap: staging → production",
  "Action": "Swap",
  "Environment": "PROD",
  "ResourceGroup": "rg-medsecure-prod",
  "AppService": "app-medsecure-prod",
  "User": "john.doe"
}
```

---

## 🏥 Conformité HDS

### Exigences HDS couvertes

| Article HDS | Exigence | Implémentation Blue/Green | Statut |
|-------------|----------|---------------------------|--------|
| **8.1** | Minimiser les interruptions de service | Swap sans downtime (< 5s) | ✅ |
| **8.2** | Plan de reprise d'activité | Rollback automatique < 30s | ✅ |
| **8.3** | Tests avant mise en production | Smoke tests obligatoires | ✅ |
| **4.1** | Traçabilité des changements | Audit trail complet | ✅ |
| **7.1** | Validation avant production | Approbations manuelles | ✅ |

### Audit trail obligatoire

Chaque déploiement génère un fichier d'audit :

**Fichier** : `DeploymentAudit/deployment-audit.json`

```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "deploymentId": "12345",
  "deploymentStrategy": "Blue/Green",
  "appService": "app-medsecure-prod",
  "resourceGroup": "rg-medsecure-prod",
  "sourceSlot": "staging",
  "targetSlot": "production",
  "swapType": "SwapWithPreview",
  "autoSwap": false,
  "rollbackEnabled": true,
  "status": "Succeeded",
  "buildNumber": "1.0.25",
  "triggeredBy": "john.doe@medsecure.fr",
  "sourceBranch": "refs/heads/main",
  "commitId": "abc123def456",
  "pipelineUrl": "https://dev.azure.com/medsecure/..."
}
```

### Conservation des logs

- **Audit trail** : 90 jours (exigence HDS)
- **Smoke test reports** : 30 jours
- **Deployment history** : 90 jours

---

## 🛠️ Dépannage

### Problème : Swap échoue avec erreur 500

**Symptôme** :
```
Error: Swap failed with HTTP 500
```

**Causes possibles** :
1. Application ne démarre pas dans le slot staging
2. Configuration manquante (connection strings, app settings)
3. Dépendance manquante (Key Vault, SQL Database)

**Solution** :
```bash
# 1. Vérifier les logs du slot staging
az webapp log tail \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod \
  --slot staging

# 2. Vérifier la configuration
az webapp config appsettings list \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod \
  --slot staging

# 3. Tester le health check manuellement
curl https://app-medsecure-prod-staging.azurewebsites.net/health
```

---

### Problème : Health check timeout

**Symptôme** :
```
❌ Health check failed after 5 attempts
```

**Causes possibles** :
1. Application démarre trop lentement (cold start)
2. Dépendances externes indisponibles
3. Configuration incorrecte

**Solution** :
```bash
# 1. Warm-up manuel
for i in {1..10}; do
  curl https://app-medsecure-prod-staging.azurewebsites.net
  sleep 5
done

# 2. Vérifier les dépendances
curl https://app-medsecure-prod-staging.azurewebsites.net/health

# 3. Augmenter le timeout dans le template
# smoke-tests.yml
parameters:
  timeout: 300  # 5 minutes au lieu de 120
```

---

### Problème : Rollback ne fonctionne pas

**Symptôme** :
```
Error: Cannot rollback - swap in progress
```

**Causes possibles** :
1. Un swap est déjà en cours
2. Le slot staging n'existe pas
3. Permissions insuffisantes

**Solution** :
```bash
# 1. Annuler le swap en cours
.\Manage-DeploymentSlots.ps1 -Action CancelSwap -Environment PROD

# 2. Vérifier l'état des slots
.\Manage-DeploymentSlots.ps1 -Action Status -Environment PROD

# 3. Retry rollback
.\Manage-DeploymentSlots.ps1 -Action Rollback -Environment PROD -Force
```

---

### Problème : Différences de configuration entre slots

**Symptôme** :
```
Application works in staging but fails in production
```

**Causes** :
- Configuration slots non synchronisée
- Settings marqués comme "slot-specific"

**Solution** :
```bash
# Comparer les configurations
az webapp config appsettings list \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod > prod-settings.json

az webapp config appsettings list \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod \
  --slot staging > staging-settings.json

# Comparer avec diff
diff prod-settings.json staging-settings.json

# Copier un setting du production vers staging
az webapp config appsettings set \
  --name app-medsecure-prod \
  --resource-group rg-medsecure-prod \
  --slot staging \
  --settings "KEY=VALUE"
```

---

## 📚 Ressources

### Documentation officielle

- **Azure App Service Slots** : https://learn.microsoft.com/azure/app-service/deploy-staging-slots
- **Blue/Green Deployment** : https://learn.microsoft.com/azure/architecture/patterns/deployment-stamp
- **Azure DevOps Deployments** : https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs

### Scripts et templates

- `pipelines/templates/deployment/blue-green-deploy.yml` - Template de déploiement
- `pipelines/templates/testing/smoke-tests.yml` - Smoke tests
- `scripts/Manage-DeploymentSlots.ps1` - Gestion manuelle
- `infra/core/host/appservice.bicep` - Infrastructure

### Guides associés

- [CI Pipeline Guide](./CI_PIPELINE_GUIDE.md)
- [DevSecOps Guide](./DEVSECOPS_GUIDE.md)
- [HDS Compliance Audit](./HDS_COMPLIANCE_AUDIT.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)

---

## ✅ Checklist de déploiement

Avant chaque déploiement en production :

### Pre-deployment
- [ ] Code merged vers `main`
- [ ] Tous les tests unitaires passent
- [ ] Security scans OK (SonarCloud, Gitleaks, Snyk, OWASP, Trivy)
- [ ] Code coverage ≥ 80%
- [ ] Changelog mis à jour
- [ ] Database migrations testées
- [ ] Feature flags configurés (si applicable)

### Deployment
- [ ] Deploy vers staging slot réussi
- [ ] Smoke tests PASSED
- [ ] Health check OK
- [ ] Response time < 2s
- [ ] SSL/TLS certificate valide
- [ ] Approbations obtenues (2 personnes)

### Post-deployment
- [ ] Swap completé avec succès
- [ ] Production health check OK
- [ ] Pas d'erreurs dans Application Insights
- [ ] Métriques de performance normales
- [ ] Tests fonctionnels validés
- [ ] Audit trail sauvegardé
- [ ] Communication aux stakeholders

### Rollback (si nécessaire)
- [ ] Décision de rollback documentée
- [ ] Rollback exécuté
- [ ] Production revenue à l'état stable
- [ ] Post-mortem planifié
- [ ] Corrections identifiées

---

**Version** : 1.0.0
**Dernière mise à jour** : 2024-01-15
**Auteur** : MedSecure DevOps Team
