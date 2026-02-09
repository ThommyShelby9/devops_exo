# Security Scanning Templates

Ce répertoire contient les templates Azure DevOps pour les scans de sécurité DevSecOps.

## 📁 Templates disponibles

| Template | Type | Objectif | Configuration |
|----------|------|----------|---------------|
| `sonarcloud.yml` | SAST | Analyse statique du code, qualité | Nécessite Service Connection SonarCloud |
| `gitleaks.yml` | Secret Detection | Détection de secrets hardcodés | Configuration via `.gitleaks.toml` |
| `snyk.yml` | SCA | Analyse des dépendances NuGet | Nécessite `SNYK_TOKEN` |
| `owasp-dependency-check.yml` | SCA | Base CVE nationale | Configuration via `.owasp-suppressions.xml` |
| `trivy.yml` | Container Scan | Scan des images Docker | Paramètres de sévérité configurables |

---

## 🔧 Configuration

### Variables requises

Créer un Variable Group `MedSecure-Security` dans Azure DevOps :

```yaml
# Variables à créer
SONAR_TOKEN: <secret>           # Token SonarCloud
SONAR_ORGANIZATION: medsecure   # Organisation SonarCloud
SONAR_PROJECT_KEY: medsecure-platform
SNYK_TOKEN: <secret>            # Token Snyk
NVD_API_KEY: <secret>           # Optionnel - NVD API Key
ACR_SERVICE_CONNECTION: ACR-MedSecure
```

### Service Connections

1. **SonarCloud**
   - Type : SonarCloud
   - Token : `SONAR_TOKEN`
   - Name : `SonarCloud`

2. **Azure Container Registry**
   - Type : Docker Registry
   - Registry : `medsecureacr.azurecr.io`
   - Name : `ACR-MedSecure`

---

## 📖 Utilisation dans les pipelines

### Exemple : Intégration complète

```yaml
# azure-pipelines.yml

stages:
  - stage: SecurityScanning
    displayName: 'Security Scanning'
    jobs:
      # SAST
      - job: SonarCloud
        steps:
          - template: pipelines/templates/security/sonarcloud.yml
            parameters:
              sonarOrganization: '$(SONAR_ORGANIZATION)'
              sonarProjectKey: '$(SONAR_PROJECT_KEY)'
              buildConfiguration: 'Release'
              failOnQualityGate: true

      # Secret Detection
      - job: Gitleaks
        steps:
          - template: pipelines/templates/security/gitleaks.yml
            parameters:
              failOnSecrets: true
              configFile: '.gitleaks.toml'

      # SCA - Snyk
      - job: Snyk
        steps:
          - template: pipelines/templates/security/snyk.yml
            parameters:
              severityThreshold: 'high'
              failOnVulnerabilities: true
              monitorProject: true

      # SCA - OWASP
      - job: OWASP
        steps:
          - template: pipelines/templates/security/owasp-dependency-check.yml
            parameters:
              scanPath: '.'
              cvssThreshold: 7.0
              failOnCvss: true

  # Container Scanning
  - stage: Docker
    jobs:
      - job: BuildAndScan
        steps:
          - task: Docker@2
            displayName: 'Build Docker image'
            inputs:
              command: 'build'
              repository: 'medsecure/web'
              tags: '$(Build.BuildId)'

          - template: pipelines/templates/security/trivy.yml
            parameters:
              imageName: 'medsecure/web'
              imageTag: '$(Build.BuildId)'
              severityLevels: 'CRITICAL,HIGH'
              failOnVulnerabilities: true
```

---

## 🎯 Paramètres des templates

### sonarcloud.yml

```yaml
parameters:
  - name: sonarOrganization
    type: string
    default: 'medsecure'

  - name: sonarProjectKey
    type: string
    default: 'medsecure-platform'

  - name: buildConfiguration
    type: string
    default: 'Release'

  - name: failOnQualityGate
    type: boolean
    default: true
```

**Sorties** :
- Rapport SonarCloud (dashboard web)
- Quality Gate status
- Code coverage, security hotspots

---

### gitleaks.yml

```yaml
parameters:
  - name: failOnSecrets
    type: boolean
    default: true

  - name: configFile
    type: string
    default: '.gitleaks.toml'
```

**Sorties** :
- `$(Build.ArtifactStagingDirectory)/gitleaks-report.json`
- Liste des secrets détectés

**Fichiers de configuration** :
- `.gitleaks.toml` - Règles personnalisées et allowlist

---

### snyk.yml

```yaml
parameters:
  - name: severityThreshold
    type: string
    default: 'high'  # low, medium, high, critical

  - name: failOnVulnerabilities
    type: boolean
    default: true

  - name: monitorProject
    type: boolean
    default: true
```

**Sorties** :
- `$(Build.ArtifactStagingDirectory)/snyk-test-report.json`
- Dashboard Snyk (si `monitorProject: true`)

**Variables requises** :
- `SNYK_TOKEN` (secret)

---

### owasp-dependency-check.yml

```yaml
parameters:
  - name: scanPath
    type: string
    default: '.'

  - name: cvssThreshold
    type: number
    default: 7.0  # CVSS score 0-10

  - name: failOnCvss
    type: boolean
    default: true
```

**Sorties** :
- `$(Build.ArtifactStagingDirectory)/owasp-reports/dependency-check-report.html`
- `$(Build.ArtifactStagingDirectory)/owasp-reports/dependency-check-report.json`
- `$(Build.ArtifactStagingDirectory)/owasp-reports/dependency-check-report.xml`

**Fichiers de configuration** :
- `.owasp-suppressions.xml` - Suppressions de faux positifs

**Variables optionnelles** :
- `NVD_API_KEY` - Améliore les rate limits NVD

---

### trivy.yml

```yaml
parameters:
  - name: imageName
    type: string

  - name: imageTag
    type: string
    default: 'latest'

  - name: severityLevels
    type: string
    default: 'CRITICAL,HIGH'

  - name: failOnVulnerabilities
    type: boolean
    default: true

  - name: scanType
    type: string
    default: 'image'  # image, filesystem, config
```

**Sorties** :
- `$(Build.ArtifactStagingDirectory)/trivy-reports/trivy-report.json`
- `$(Build.ArtifactStagingDirectory)/trivy-reports/trivy-report.txt`
- `$(Build.ArtifactStagingDirectory)/trivy-reports/trivy-report.sarif`

---

## 📊 Seuils de conformité HDS

| Scanner | Métrique | Objectif | Bloquant |
|---------|----------|----------|----------|
| **SonarCloud** | Code Coverage | ≥ 80% | ✅ |
| **SonarCloud** | Security Hotspots | 0 | ✅ |
| **Gitleaks** | Secrets détectés | 0 | ✅ |
| **Snyk** | High/Critical | < 5 | ✅ |
| **OWASP** | CVSS ≥ 7.0 | 0 | ✅ |
| **Trivy** | Critical/High | 0 | ✅ |

---

## 🔄 Ordre d'exécution recommandé

### Option 1 : Parallèle (plus rapide)

```yaml
- stage: SecurityScanning
  dependsOn: []  # Run in parallel with Build
  jobs:
    - job: SonarCloud
    - job: Gitleaks
    - job: Snyk
    - job: OWASP
```

**Avantages** :
- ⚡ Temps de pipeline réduit (~40%)
- Détection précoce des problèmes

**Inconvénients** :
- Consomme plus de ressources Azure DevOps

---

### Option 2 : Séquentiel (plus économique)

```yaml
- stage: SecurityScanning
  dependsOn: Build
  jobs:
    - job: AllSecurityScans
      steps:
        - template: pipelines/templates/security/sonarcloud.yml
        - template: pipelines/templates/security/gitleaks.yml
        - template: pipelines/templates/security/snyk.yml
        - template: pipelines/templates/security/owasp-dependency-check.yml
```

**Avantages** :
- 💰 Coût réduit (1 seul agent)
- Logs groupés

**Inconvénients** :
- ⏱️ Temps plus long (~2x)

---

## 🛠️ Dépannage

### SonarCloud : Token invalide

```bash
# Vérifier le token
curl -u $(SONAR_TOKEN): https://sonarcloud.io/api/authentication/validate

# Régénérer le token
# https://sonarcloud.io/account/security
```

### Gitleaks : Trop de faux positifs

```toml
# Ajouter dans .gitleaks.toml
[allowlist]
paths = [
    '''tests/''',
    '''Migrations/''',
]
```

### Snyk : Authentification échouée

```bash
# Vérifier le token
curl -H "Authorization: token $(SNYK_TOKEN)" https://api.snyk.io/v1/user/me
```

### OWASP : Scan trop lent

```yaml
# Activer le cache NVD
- task: Cache@2
  inputs:
    key: 'owasp-nvd | "$(Agent.OS)"'
    path: '$(Pipeline.Workspace)/.owasp/data'
```

### Trivy : Image non trouvée

```yaml
# S'assurer que l'image est construite avant
- task: Docker@2
  displayName: 'Build Docker image'
  # ... build configuration

- template: pipelines/templates/security/trivy.yml
  # Image existe maintenant
```

---

## 📚 Documentation complète

- **Guide DevSecOps** : [docs/DEVSECOPS_GUIDE.md](../../../docs/DEVSECOPS_GUIDE.md)
- **Référence rapide** : [docs/SECURITY_QUICK_REFERENCE.md](../../../docs/SECURITY_QUICK_REFERENCE.md)
- **HDS Compliance** : [docs/HDS_COMPLIANCE_AUDIT.md](../../../docs/HDS_COMPLIANCE_AUDIT.md)

---

## 🔗 Liens utiles

- **SonarCloud** : https://sonarcloud.io
- **Gitleaks** : https://github.com/gitleaks/gitleaks
- **Snyk** : https://snyk.io
- **OWASP Dependency Check** : https://jeremylong.github.io/DependencyCheck
- **Trivy** : https://aquasecurity.github.io/trivy

---

**Version** : 1.0.0
**Dernière mise à jour** : 2024-01-15
**Maintenu par** : MedSecure DevOps Team
