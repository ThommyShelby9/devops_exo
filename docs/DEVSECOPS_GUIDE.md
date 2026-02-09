# Guide DevSecOps - MedSecure

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture de sécurité](#architecture-de-sécurité)
3. [Outils de scanning](#outils-de-scanning)
4. [Configuration du pipeline](#configuration-du-pipeline)
5. [Hooks Git locaux](#hooks-git-locaux)
6. [Interprétation des résultats](#interprétation-des-résultats)
7. [Conformité HDS](#conformité-hds)
8. [Dépannage](#dépannage)

---

## 🎯 Vue d'ensemble

### Qu'est-ce que DevSecOps ?

**DevSecOps** = Development + Security + Operations

Intégration de la sécurité **dès le début** du cycle de développement, pas à la fin.

### Objectifs pour MedSecure

- ✅ Détecter les vulnérabilités **avant** la production
- ✅ Empêcher les secrets d'être committés
- ✅ Maintenir la conformité **HDS** et **RGPD**
- ✅ Automatiser les audits de sécurité
- ✅ Traçabilité complète (ISO 27001)

### Couches de sécurité

```
┌─────────────────────────────────────────────┐
│  Developer Workstation (Pre-commit hooks)   │  ← Gitleaks (local)
├─────────────────────────────────────────────┤
│  Source Control (Git)                       │  ← Branch protection
├─────────────────────────────────────────────┤
│  CI Pipeline (Azure DevOps)                 │  ← 5 security scanners
│   ├─ SonarCloud (SAST)                      │
│   ├─ Gitleaks (Secrets)                     │
│   ├─ Snyk (SCA)                             │
│   ├─ OWASP Dependency Check                 │
│   └─ Trivy (Container)                      │
├─────────────────────────────────────────────┤
│  Container Registry (ACR)                   │  ← Quarantine, trust policy
├─────────────────────────────────────────────┤
│  Staging Environment                        │  ← Runtime monitoring
├─────────────────────────────────────────────┤
│  Production Environment                     │  ← Azure Defender, alerts
└─────────────────────────────────────────────┘
```

---

## 🏗️ Architecture de sécurité

### Pipeline de sécurité

Le pipeline MedSecure intègre **5 scanners de sécurité** :

| Scanner | Type | Objectif | Sévérité | Bloque le build |
|---------|------|----------|----------|-----------------|
| **SonarCloud** | SAST | Code statique, qualité | Quality Gate | ✅ Oui |
| **Gitleaks** | Secret Detection | Secrets, clés API | Tous | ✅ Oui |
| **Snyk** | SCA | Dépendances NuGet | High+ | ✅ Oui |
| **OWASP Dependency Check** | SCA | CVE database | CVSS ≥ 7.0 | ✅ Oui |
| **Trivy** | Container Scan | Images Docker | Critical/High | ✅ Oui |

### Stratégie "Shift Left"

```
Traditional Security          DevSecOps (Shift Left)
─────────────────────────────────────────────────────
Dev → Test → Prod → Security    Security → Dev → Test → Prod
        ↑                        ↑
    (Too late!)              (Early detection!)
```

---

## 🔍 Outils de scanning

### 1. SonarCloud (SAST)

**SAST** = Static Application Security Testing

#### Qu'est-ce que c'est ?
Analyse le **code source** sans l'exécuter pour détecter :
- Vulnérabilités de sécurité (OWASP Top 10)
- Bugs de code
- Code smells
- Couverture de tests

#### Configuration

**Fichier** : `pipelines/templates/security/sonarcloud.yml`

```yaml
parameters:
  sonarOrganization: 'medsecure'
  sonarProjectKey: 'medsecure-platform'
  failOnQualityGate: true
```

**Variables Azure DevOps requises** :
- `SONAR_TOKEN` (secret) - Token d'authentification SonarCloud
- `SONAR_ORGANIZATION` - Nom de l'organisation
- `SONAR_PROJECT_KEY` - Clé du projet

#### Obtenir un token SonarCloud

1. Aller sur https://sonarcloud.io
2. Se connecter avec GitHub/Azure DevOps
3. **My Account** → **Security** → **Generate Token**
4. Copier le token dans Azure DevOps :
   - **Pipelines** → **Library** → **Variable Groups**
   - Créer variable `SONAR_TOKEN` (type: secret)

#### Quality Gate

Le Quality Gate échoue si :
- ❌ Couverture de code < 80%
- ❌ Nouvelles vulnérabilités (security hotspots)
- ❌ Code duplications > 3%
- ❌ Maintainability rating < A

#### Règles de sécurité activées

- **SQL Injection** (squid:S3649)
- **XSS** (squid:S5131)
- **CSRF** (squid:S4502)
- **Hardcoded credentials** (squid:S2068)
- **Weak cryptography** (squid:S4426)
- **Path traversal** (squid:S2083)

#### Exemple de résultat

```
✅ Quality Gate: PASSED
────────────────────────────────────────
Code Coverage:        85.2% ✅
Security Hotspots:    0     ✅
Bugs:                 3     ⚠️
Code Smells:          12    ⚠️
Duplications:         1.8%  ✅
────────────────────────────────────────
```

---

### 2. Gitleaks (Secret Detection)

#### Qu'est-ce que c'est ?
Scanne le code pour détecter des **secrets** :
- 🔑 Clés API
- 🔐 Passwords
- 🎫 Tokens d'accès
- 📜 Certificats privés
- 💳 Connection strings avec mot de passe

#### Configuration

**Fichier** : `.gitleaks.toml`

```toml
[allowlist]
description = "Allowlist for false positives"
regexes = [
    '''Server=\(localdb\)''',  # LocalDB OK
    '''localhost''',            # Localhost OK
]

paths = [
    '''tests/''',               # Ignore tests
    '''Migrations/''',          # Ignore migrations
]
```

#### Règles personnalisées pour la santé

```toml
[[rules]]
id = "patient-data-key"
description = "Patient Data Encryption Key"
regex = '''(?i)(patient[_-]?data[_-]?key)'''
tags = ["healthcare", "hds"]

[[rules]]
id = "ins-patient-identifier"
description = "INS (Identifiant National de Santé)"
regex = '''(?i)(ins[_-]?number)[_-]?[:=]\s*\d{15}'''
tags = ["hds", "rgpd", "france"]
```

#### Utilisation locale

```bash
# Scanner tous les fichiers
gitleaks detect --source . --verbose

# Scanner seulement les fichiers staged
gitleaks protect --staged

# Générer un rapport JSON
gitleaks detect --report-path report.json --report-format json
```

#### Exemple de détection

```json
{
  "Description": "Azure Storage Account Key",
  "File": "appsettings.json",
  "Line": 12,
  "Secret": "AccountKey=xyz123abc...",
  "Match": "AccountKey=xyz123abc456def789...",
  "StartLine": 12,
  "EndLine": 12
}
```

#### Actions en cas de détection

1. ❌ **NE JAMAIS** committer le secret
2. 🔄 Révoquer/regénérer la clé immédiatement
3. 🔐 Stocker dans Azure Key Vault
4. 📝 Utiliser des références Key Vault
5. ✅ Re-scanner avant commit

---

### 3. Snyk (Software Composition Analysis)

#### Qu'est-ce que c'est ?
Analyse les **dépendances NuGet** pour détecter des vulnérabilités connues.

#### Configuration

**Fichier** : `pipelines/templates/security/snyk.yml`

```yaml
parameters:
  severityThreshold: 'high'
  failOnVulnerabilities: true
  monitorProject: true
```

**Variables requises** :
- `SNYK_TOKEN` (secret) - Token d'authentification Snyk

#### Obtenir un token Snyk

1. Aller sur https://snyk.io
2. Créer un compte (gratuit pour open-source)
3. **Settings** → **General** → **API Token**
4. Copier dans Azure DevOps Library

#### Seuils de sévérité

- **Critical** : Exploitation active, patch disponible
- **High** : Exploitation possible, impact élevé
- **Medium** : Exploitation difficile, impact modéré
- **Low** : Impact faible, exploitation théorique

#### Exemple de résultat

```
✅ Snyk Test Summary
────────────────────────────────────────
Project: MedSecure.Web
  - Vulnerabilities: 5
  - Critical: 0 ✅
  - High: 2     ⚠️
  - Medium: 2   ⚠️
  - Low: 1      ℹ️

High Severity Vulnerabilities:
  1. System.Text.Json < 8.0.1
     CVE-2024-12345 - Denial of Service
     Fix: Upgrade to 8.0.1+

  2. Microsoft.Data.SqlClient < 5.1.2
     CVE-2024-67890 - SQL Injection
     Fix: Upgrade to 5.1.2+
────────────────────────────────────────
```

#### Dashboard Snyk

Snyk envoie les résultats vers un dashboard central :
- 📊 Tendances de sécurité
- 📈 Évolution des vulnérabilités
- 🎯 Priorités de correction
- 📧 Alertes automatiques

---

### 4. OWASP Dependency Check

#### Qu'est-ce que c'est ?
Scanner **complémentaire** à Snyk qui utilise la base CVE nationale (NVD).

#### Configuration

**Fichier** : `pipelines/templates/security/owasp-dependency-check.yml`

```yaml
parameters:
  scanPath: '.'
  cvssThreshold: 7.0    # CVSS v3.1 score
  failOnCvss: true
```

**Variables requises** :
- `NVD_API_KEY` (optionnel) - Clé API NVD pour taux limites plus élevés

#### Obtenir une clé NVD API

1. Aller sur https://nvd.nist.gov/developers/request-an-api-key
2. Remplir le formulaire
3. Recevoir la clé par email
4. Ajouter dans Azure DevOps Library

#### Score CVSS

**CVSS** = Common Vulnerability Scoring System (0.0 - 10.0)

| Score | Sévérité | Action |
|-------|----------|--------|
| 9.0-10.0 | **Critical** | Patch immédiat (< 24h) |
| 7.0-8.9 | **High** | Patch urgent (< 7 jours) |
| 4.0-6.9 | **Medium** | Patch planifié (< 30 jours) |
| 0.1-3.9 | **Low** | À évaluer |

#### Fichier de suppressions

**Fichier** : `.owasp-suppressions.xml`

```xml
<suppress>
  <notes><![CDATA[
    CVE-2024-12345 est un faux positif
    Notre version n'est pas affectée
    Reviewed: 2024-01-15 by Security Team
    Expires: 2024-07-15
  ]]></notes>
  <packageUrl regex="true">^pkg:nuget/Package.*$</packageUrl>
  <cve>CVE-2024-12345</cve>
</suppress>
```

⚠️ **HDS Compliance** : Toute suppression doit être :
1. Documentée avec justification
2. Revue par l'équipe sécurité
3. Limitée dans le temps (max 6 mois)
4. Réévaluée à expiration

#### Formats de rapport

- **HTML** : Visualisation facile
- **JSON** : Intégration CI/CD
- **XML** : Import dans outils SIEM
- **CSV** : Analyse Excel

---

### 5. Trivy (Container Security)

#### Qu'est-ce que c'est ?
Scanner de **sécurité des containers** Docker.

#### Configuration

**Fichier** : `pipelines/templates/security/trivy.yml`

```yaml
parameters:
  imageName: 'medsecure/web'
  imageTag: 'latest'
  severityLevels: 'CRITICAL,HIGH'
  failOnVulnerabilities: true
  scanType: 'image'
```

#### Types de scan

1. **Image** : Scanne l'image Docker complète
   ```bash
   trivy image medsecure/web:latest
   ```

2. **Filesystem** : Scanne les fichiers du projet
   ```bash
   trivy fs .
   ```

3. **Config** : Scanne les fichiers de configuration (Dockerfile, K8s)
   ```bash
   trivy config ./Dockerfile
   ```

#### Ce que Trivy détecte

- ✅ Vulnérabilités OS (Alpine, Ubuntu, Debian)
- ✅ Vulnérabilités dans les bibliothèques
- ✅ Misconfigurations (Dockerfile)
- ✅ Secrets hardcodés
- ✅ Licences des packages

#### Exemple de résultat

```
📊 Trivy Scan Results
════════════════════════════════════════
Image: medsecure/web:1.0.0

Total: 45 vulnerabilities
  - Critical: 2  ❌
  - High: 8      ⚠️
  - Medium: 20   ⚠️
  - Low: 15      ℹ️

Critical Vulnerabilities:
────────────────────────────────────────
1. CVE-2024-12345
   Package: libssl1.1
   Severity: CRITICAL (CVSS 9.8)
   Fixed: 1.1.1w-r0
   Description: Remote code execution

2. CVE-2024-67890
   Package: zlib
   Severity: CRITICAL (CVSS 9.1)
   Fixed: 1.2.13-r2
   Description: Buffer overflow
════════════════════════════════════════

❌ Build FAILED due to critical vulnerabilities
```

#### Bonnes pratiques Dockerfile

```dockerfile
# ✅ Utiliser des images officielles
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# ✅ Spécifier des versions exactes
FROM mcr.microsoft.com/dotnet/aspnet:8.0.1

# ✅ Utiliser des images "distroless" ou minimales
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine

# ✅ Ne pas exécuter en tant que root
RUN groupadd -r medsecure && useradd -r -g medsecure medsecure
USER medsecure

# ❌ Ne pas copier des secrets
# COPY appsettings.Production.json .   # NON!

# ✅ Scanner régulièrement
# trivy image medsecure/web:latest
```

#### ACR Integration

Azure Container Registry intègre Trivy automatiquement :
- 🔒 Quarantine des images vulnérables
- 📝 Signature d'images (content trust)
- 🚫 Blocage des images non-signées

---

## ⚙️ Configuration du pipeline

### Structure du pipeline

```yaml
# azure-pipelines.yml

stages:
  # Stage 1: Build & Test
  - stage: Build
    jobs:
      - Build .NET 8
      - Run unit tests
      - Publish artifacts

  # Stage 2: Security Scanning (Parallel)
  - stage: SecurityScanning
    dependsOn: []  # Run in parallel
    jobs:
      - SonarCloud (SAST)
      - Gitleaks (Secrets)
      - Snyk (SCA)
      - OWASP (CVE)

  # Stage 3: Docker Build & Scan
  - stage: Docker
    dependsOn: Build
    jobs:
      - Build Docker image
      - Trivy scan
      - Push to ACR

  # Stage 4: Deploy to DEV (Auto)
  - stage: DeployDev
    dependsOn: [Build, SecurityScanning, Docker]

  # Stage 5: Deploy to STAGING (Manual)
  - stage: DeployStaging
    dependsOn: [Build, SecurityScanning, Docker]

  # Stage 6: Deploy to PROD (Manual)
  - stage: DeployProduction
    dependsOn: DeployStaging
```

### Variables Azure DevOps

#### Créer un Variable Group

1. **Pipelines** → **Library** → **+ Variable group**
2. Nom : `MedSecure-Security`
3. Ajouter les variables :

| Variable | Type | Valeur | Description |
|----------|------|--------|-------------|
| `SONAR_TOKEN` | Secret | `xxx` | Token SonarCloud |
| `SONAR_ORGANIZATION` | Text | `medsecure` | Organisation SonarCloud |
| `SONAR_PROJECT_KEY` | Text | `medsecure-platform` | Clé projet SonarCloud |
| `SNYK_TOKEN` | Secret | `xxx` | Token Snyk |
| `NVD_API_KEY` | Secret | `xxx` | Clé API NVD (optionnel) |
| `ACR_SERVICE_CONNECTION` | Text | `ACR-MedSecure` | Nom de la connexion ACR |

#### Lier le Variable Group au pipeline

```yaml
# azure-pipelines.yml

variables:
  - group: MedSecure-Security  # ← Importer le groupe
  - name: buildConfiguration
    value: 'Release'
```

### Service Connections

#### Azure Container Registry

1. **Project Settings** → **Service connections**
2. **+ New service connection** → **Docker Registry**
3. Type : **Azure Container Registry**
4. Subscription : Sélectionner votre abonnement Azure
5. Registry : `medsecureacr.azurecr.io`
6. Service connection name : `ACR-MedSecure`

#### SonarCloud

1. **Project Settings** → **Service connections**
2. **+ New service connection** → **SonarCloud**
3. Token : Coller votre `SONAR_TOKEN`
4. Service connection name : `SonarCloud`

---

## 🔐 Hooks Git locaux

### Installation

```bash
# Exécuter le script d'installation
cd scripts
chmod +x install-git-hooks.sh
./install-git-hooks.sh
```

### Hooks installés

#### 1. Pre-commit Hook

**But** : Empêcher de committer des secrets

```bash
# Triggered on: git commit
🔍 Running Gitleaks secret detection...
✅ No secrets detected!
```

Si des secrets sont détectés :
```bash
❌ SECRETS DETECTED!

Gitleaks found potential secrets in your staged files.

Options:
  1. Remove the secrets and commit again
  2. Add false positives to .gitleaks.toml allowlist
  3. Use git commit --no-verify (NOT RECOMMENDED for HDS compliance)
```

#### 2. Commit-msg Hook

**But** : Valider le format des messages de commit

Format attendu : `type(scope): subject`

Types valides :
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation
- `style`: Formatage
- `refactor`: Refactoring
- `test`: Tests
- `chore`: Maintenance
- `perf`: Performance
- `ci`: CI/CD
- `build`: Build système
- `revert`: Revert

Exemples valides :
```bash
✅ feat(auth): add OAuth2 authentication
✅ fix(api): resolve null reference in patient controller
✅ docs(readme): update deployment instructions
✅ test(patient): add unit tests for patient service
✅ chore(deps): update Microsoft.AspNetCore to 8.0.1
```

Exemples invalides :
```bash
❌ added new feature
❌ fix bug
❌ WIP
❌ fixed stuff
```

#### 3. Pre-push Hook

**But** : Exécuter les tests unitaires avant push

```bash
# Triggered on: git push
🧪 Running unit tests before push...
✅ All tests passed!
```

### Bypass des hooks (NON RECOMMANDÉ)

```bash
# Bypass pre-commit
git commit --no-verify

# Bypass pre-push
git push --no-verify
```

⚠️ **HDS Compliance** : Le bypass des hooks n'est **pas recommandé** et doit être tracé dans les audits.

---

## 📊 Interprétation des résultats

### Rapports générés

Chaque scanner génère des rapports dans `$(Build.ArtifactStagingDirectory)` :

```
Build Artifacts
├── SecurityReports/
│   ├── sonarcloud-report.json
│   ├── gitleaks-report.json
│   ├── snyk-test-report.json
│   ├── owasp-reports/
│   │   ├── dependency-check-report.html
│   │   ├── dependency-check-report.json
│   │   └── dependency-check-report.xml
│   └── trivy-reports/
│       ├── trivy-report.json
│       ├── trivy-report.txt
│       └── trivy-report.sarif
```

### Accès aux rapports

1. **Azure DevOps** → **Pipelines**
2. Sélectionner un run de pipeline
3. **Artifacts** → **SecurityReports**
4. Télécharger les rapports

### Dashboard centralisé

#### Option 1 : Azure DevOps Dashboards

Créer un dashboard personnalisé :
1. **Overview** → **Dashboards** → **+ New Dashboard**
2. Ajouter des widgets :
   - **Build History**
   - **Test Results**
   - **Work Items** (bugs de sécurité)
   - **Chart for Work Items** (tendances)

#### Option 2 : SonarCloud Dashboard

https://sonarcloud.io/organizations/medsecure/projects

- 📊 Métriques de qualité
- 🐛 Bugs de sécurité
- 📈 Tendances historiques
- 🎯 Quality Gate status

#### Option 3 : Snyk Dashboard

https://app.snyk.io

- 📊 Vulnérabilités par projet
- 📈 Évolution dans le temps
- 🎯 Priorités de correction
- 📧 Alertes email automatiques

### Métriques clés

| Métrique | Objectif HDS | Seuil Critique |
|----------|--------------|----------------|
| Code Coverage | ≥ 80% | < 70% |
| Security Hotspots | 0 | > 5 |
| Critical Vulnerabilities | 0 | > 0 |
| High Vulnerabilities | < 5 | > 10 |
| Secrets detected | 0 | > 0 |
| CVSS Score | < 7.0 | ≥ 9.0 |

---

## 🏥 Conformité HDS

### Exigences HDS pour DevSecOps

#### 1. Sécurité du code (Article 3.1)

| Exigence | Implémentation MedSecure |
|----------|--------------------------|
| SAST (Static Analysis) | ✅ SonarCloud |
| SCA (Dependency Scan) | ✅ Snyk + OWASP |
| Secret Detection | ✅ Gitleaks (local + CI) |
| Container Security | ✅ Trivy |
| Code Review | ✅ Pull Requests obligatoires |

#### 2. Gestion des vulnérabilités (Article 3.2)

| Sévérité | SLA de correction | Responsable |
|----------|-------------------|-------------|
| **Critical** (CVSS ≥ 9.0) | < 24h | Security Team |
| **High** (CVSS 7.0-8.9) | < 7 jours | Dev Team Lead |
| **Medium** (CVSS 4.0-6.9) | < 30 jours | Dev Team |
| **Low** (CVSS < 4.0) | Backlog | Product Owner |

#### 3. Traçabilité (Article 4.1)

Tous les scans de sécurité doivent être :
- ✅ **Enregistrés** dans Azure DevOps
- ✅ **Horodatés** (timestamp de chaque scan)
- ✅ **Archivés** (90 jours minimum)
- ✅ **Auditables** (rapports JSON/SARIF)

#### 4. Séparation des environnements (Article 5.1)

```
DEV (develop branch)
  ↓ (Auto-deploy after security scan)
STAGING (main branch)
  ↓ (Manual approval required)
PRODUCTION (main branch)
  ↓ (Manual approval + security validation)
```

#### 5. Gestion des secrets (Article 6.1)

| Mauvaise pratique | Bonne pratique |
|-------------------|----------------|
| ❌ Hardcoded passwords | ✅ Azure Key Vault |
| ❌ appsettings.json | ✅ Key Vault references |
| ❌ Environment variables | ✅ Managed Identity |
| ❌ Commit secrets to Git | ✅ Gitleaks pre-commit |

### Audit trail

#### Logs de sécurité

Chaque scan génère une entrée dans Azure DevOps :

```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "pipeline": "MedSecure-CI",
  "buildId": "12345",
  "stage": "SecurityScanning",
  "job": "SonarCloud",
  "result": "succeeded",
  "duration": "2m 15s",
  "artifacts": [
    "sonarcloud-report.json"
  ],
  "quality_gate": "PASSED",
  "vulnerabilities": {
    "critical": 0,
    "high": 0,
    "medium": 2,
    "low": 5
  }
}
```

#### Requêtes KQL pour audit

Azure Monitor - Log Analytics Workspace :

```kql
// Tous les scans de sécurité des 30 derniers jours
AzureDevOpsPipelines
| where TimeGenerated > ago(30d)
| where StageName == "SecurityScanning"
| summarize count() by JobName, Result

// Vulnérabilités critiques détectées
AzureDevOpsPipelines
| where TimeGenerated > ago(90d)
| where JobName in ("SonarCloud", "Snyk", "OWASP", "Trivy")
| where Result == "failed"
| project TimeGenerated, BuildId, JobName, ErrorMessage
| order by TimeGenerated desc

// Taux de réussite des scans
AzureDevOpsPipelines
| where TimeGenerated > ago(30d)
| where StageName == "SecurityScanning"
| summarize
    Total = count(),
    Succeeded = countif(Result == "succeeded"),
    Failed = countif(Result == "failed")
    by JobName
| extend SuccessRate = (Succeeded * 100.0) / Total
```

### Procédure de remédiation

#### 1. Détection

Pipeline détecte une vulnérabilité Critical/High :
```
❌ CRITICAL: CVE-2024-12345 found in System.Text.Json
   CVSS: 9.8
   Fix: Upgrade to version 8.0.1+
```

#### 2. Notification

- 📧 Email automatique aux Security Team
- 🔔 Notification Teams/Slack
- 🐛 Création automatique d'un Work Item Azure DevOps

#### 3. Évaluation (< 4h)

Security Team évalue :
- Impact sur MedSecure
- Exploitabilité
- Disponibilité d'un patch
- Workaround possible

#### 4. Correction (selon SLA)

- **Critical** : Hotfix branch → Patch → Déploiement d'urgence (< 24h)
- **High** : Feature branch → Sprint en cours (< 7 jours)
- **Medium/Low** : Backlog → Sprint planning

#### 5. Vérification

- ✅ Re-run pipeline de sécurité
- ✅ Validation Security Team
- ✅ Tests de non-régression
- ✅ Déploiement en production

#### 6. Documentation

- 📝 Post-mortem (pour Critical)
- 📊 Mise à jour du registre des risques
- 📧 Communication aux stakeholders

---

## 🛠️ Dépannage

### Problème : SonarCloud échoue

#### Symptôme
```
Error: No analysis found for this build
```

#### Causes possibles
1. Token SonarCloud invalide
2. Organisation/Projet incorrects
3. Quality Gate trop strict

#### Solution
```bash
# 1. Vérifier le token
az pipelines variable-group variable list \
  --group-id <group-id> \
  --org https://dev.azure.com/medsecure

# 2. Vérifier la connexion SonarCloud
# Azure DevOps → Project Settings → Service connections → SonarCloud

# 3. Ajuster le Quality Gate temporairement
# SonarCloud → Quality Gates → Create/Edit
```

---

### Problème : Gitleaks génère trop de faux positifs

#### Symptôme
```
❌ Secrets detected in appsettings.Development.json
```

#### Solution

Ajouter à `.gitleaks.toml` :

```toml
[allowlist]
paths = [
    '''appsettings\.Development\.json''',
    '''appsettings\.Local\.json''',
]

regexes = [
    '''Server=\(localdb\)\\mssqllocaldb''',
    '''localhost:5000''',
]
```

---

### Problème : Snyk échoue sur dépendances privées

#### Symptôme
```
Error: Could not authenticate to NuGet feed
```

#### Solution

Configurer l'authentification NuGet :

```yaml
# pipelines/templates/security/snyk.yml
steps:
  - task: NuGetAuthenticate@1
    displayName: 'Authenticate to NuGet feeds'

  - script: snyk test --all-projects
    env:
      SNYK_TOKEN: $(SNYK_TOKEN)
```

---

### Problème : OWASP Dependency Check trop lent

#### Symptôme
```
OWASP scan running for 20+ minutes
```

#### Solution

1. **Activer le cache** :
```yaml
- task: Cache@2
  inputs:
    key: 'owasp-nvd | "$(Agent.OS)"'
    path: '$(Pipeline.Workspace)/.owasp/data'
```

2. **Utiliser une clé NVD API** (rate limits plus élevés)

3. **Scanner seulement les dépendances changées** :
```bash
dependency-check.sh \
  --scan "src/**/*.csproj" \
  --enableExperimental \
  --nvdApiKey "$(NVD_API_KEY)"
```

---

### Problème : Trivy ne trouve pas l'image Docker

#### Symptôme
```
Error: image not found
```

#### Solution

Vérifier que l'image est construite avant le scan :

```yaml
steps:
  - task: Docker@2
    displayName: 'Build Docker image'
    inputs:
      command: 'build'
      repository: '$(imageName)'
      tags: '$(imageTag)'

  # ✅ L'image existe maintenant
  - template: pipelines/templates/security/trivy.yml
    parameters:
      imageName: '$(imageName)'
      imageTag: '$(imageTag)'
```

---

### Problème : Pipeline bloqué par Quality Gate

#### Symptôme
```
Quality Gate failed: Code coverage 75% (threshold: 80%)
```

#### Actions

**Option 1 : Augmenter la couverture de tests** (recommandé)
```bash
# Identifier le code non couvert
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura

# Ajouter des tests
```

**Option 2 : Ajuster temporairement le seuil**
```yaml
# azure-pipelines.yml
variables:
  coverageThreshold: 75  # Temporaire, documenter la raison
```

**Option 3 : Bypass temporaire** (NON RECOMMANDÉ)
```yaml
- template: pipelines/templates/security/sonarcloud.yml
  parameters:
    failOnQualityGate: false  # ⚠️ Documenter pourquoi!
```

---

## 📚 Ressources supplémentaires

### Documentation officielle

- **SonarCloud** : https://docs.sonarcloud.io
- **Gitleaks** : https://github.com/gitleaks/gitleaks
- **Snyk** : https://docs.snyk.io
- **OWASP Dependency Check** : https://jeremylong.github.io/DependencyCheck
- **Trivy** : https://aquasecurity.github.io/trivy

### Standards de sécurité

- **OWASP Top 10** : https://owasp.org/Top10
- **CWE Top 25** : https://cwe.mitre.org/top25
- **CVSS Calculator** : https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator

### HDS/RGPD

- **Certification HDS** : https://esante.gouv.fr/labels-certifications/hds
- **RGPD** : https://www.cnil.fr/fr/reglement-europeen-protection-donnees
- **ISO 27001** : https://www.iso.org/isoiec-27001-information-security.html

---

## 🎯 Checklist DevSecOps

Avant chaque release en production :

- [ ] ✅ Tous les scans de sécurité passent (SonarCloud, Gitleaks, Snyk, OWASP, Trivy)
- [ ] ✅ Aucune vulnérabilité Critical/High
- [ ] ✅ Code coverage ≥ 80%
- [ ] ✅ Quality Gate SonarCloud = PASSED
- [ ] ✅ Aucun secret détecté par Gitleaks
- [ ] ✅ Image Docker signée et scannée
- [ ] ✅ Tous les tests passent (unit, integration, functional)
- [ ] ✅ Approbation Security Team
- [ ] ✅ Documentation mise à jour
- [ ] ✅ Logs et traces activés
- [ ] ✅ Backup validé
- [ ] ✅ Plan de rollback prêt

---

## 📞 Support

Pour toute question sur DevSecOps :

- **Équipe Sécurité** : security@medsecure.fr
- **DevOps Team** : devops@medsecure.fr
- **Documentation** : https://docs.medsecure.fr
- **Incidents** : https://medsecure.atlassian.net

---

**Dernière mise à jour** : 2024-01-15
**Version** : 1.0.0
**Auteur** : MedSecure Security Team
