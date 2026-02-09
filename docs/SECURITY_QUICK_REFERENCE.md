# Guide de Référence Rapide - Sécurité DevSecOps

## 🚀 Quick Start (5 minutes)

### 1. Installation des hooks Git

```bash
cd scripts
chmod +x install-git-hooks.sh
./install-git-hooks.sh
```

✅ Installe : Gitleaks (pre-commit), format validation (commit-msg), tests (pre-push)

### 2. Scanner localement avant commit

```bash
# Scanner pour des secrets
gitleaks detect --verbose

# Scanner seulement les fichiers staged
gitleaks protect --staged

# Scanner les dépendances .NET
dotnet list package --vulnerable --include-transitive

# Scanner l'image Docker
docker build -t medsecure/web:test .
trivy image medsecure/web:test
```

### 3. Format de commit

```bash
# ✅ BON
git commit -m "feat(auth): add OAuth2 authentication"
git commit -m "fix(api): resolve null reference in patient service"
git commit -m "docs(readme): update deployment instructions"

# ❌ MAUVAIS
git commit -m "fixed stuff"
git commit -m "WIP"
git commit -m "update"
```

---

## 🔍 Scanners de sécurité

| Scanner | Commande locale | Objectif |
|---------|----------------|----------|
| **Gitleaks** | `gitleaks detect` | Secrets, clés API |
| **SonarCloud** | Via IDE plugin | Code quality, SAST |
| **Snyk** | `snyk test` | Dépendances NuGet |
| **OWASP** | `dependency-check.sh --scan .` | CVE database |
| **Trivy** | `trivy image <image>` | Container scan |

---

## ⚠️ Actions en cas de détection

### Secret détecté par Gitleaks

```bash
❌ SECRETS DETECTED!
```

**Actions** :
1. ❌ **NE PAS** committer
2. 🔐 Révoquer le secret immédiatement
3. 🔑 Stocker dans Azure Key Vault
4. 📝 Utiliser des références Key Vault
5. ✅ Re-scanner : `gitleaks protect --staged`

### Vulnérabilité détectée

```bash
❌ HIGH: CVE-2024-12345 in System.Text.Json
```

**Actions** :
1. 📊 Vérifier la sévérité (Critical/High/Medium/Low)
2. 📦 Mettre à jour le package : `dotnet add package System.Text.Json --version 8.0.1`
3. ✅ Re-tester : `dotnet test`
4. 🔍 Re-scanner : `snyk test`

---

## 🏥 Conformité HDS - SLA de correction

| Sévérité | CVSS | SLA | Action |
|----------|------|-----|--------|
| **Critical** | 9.0-10.0 | **< 24h** | Hotfix immédiat |
| **High** | 7.0-8.9 | **< 7 jours** | Sprint en cours |
| **Medium** | 4.0-6.9 | **< 30 jours** | Planifié |
| **Low** | 0.1-3.9 | Backlog | À évaluer |

---

## 🔐 Bonnes pratiques

### Gestion des secrets

```csharp
// ❌ MAUVAIS - Hardcoded secret
var apiKey = "sk_live_abc123def456";

// ✅ BON - Azure Key Vault
var keyVaultUrl = Configuration["KeyVault:VaultUrl"];
var secretClient = new SecretClient(new Uri(keyVaultUrl), new DefaultAzureCredential());
var apiKey = (await secretClient.GetSecretAsync("ApiKey")).Value.Value;

// ✅ BON - Key Vault reference dans appsettings.json
{
  "ApiKey": "@Microsoft.KeyVault(SecretUri=https://medsecure-kv.vault.azure.net/secrets/ApiKey/)"
}
```

### Dépendances sécurisées

```xml
<!-- ❌ MAUVAIS - Version flexible -->
<PackageReference Include="Newtonsoft.Json" Version="12.*" />

<!-- ✅ BON - Version exacte -->
<PackageReference Include="Newtonsoft.Json" Version="13.0.3" />

<!-- ✅ BON - Audit régulier -->
<!-- dotnet list package --vulnerable --include-transitive -->
```

### Dockerfile sécurisé

```dockerfile
# ✅ BON - Image officielle, version exacte
FROM mcr.microsoft.com/dotnet/aspnet:8.0.1-alpine

# ✅ BON - Utilisateur non-root
RUN addgroup -S medsecure && adduser -S medsecure -G medsecure
USER medsecure

# ✅ BON - Health check
HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# ❌ MAUVAIS - Copier des secrets
# COPY appsettings.Production.json .
```

---

## 📊 Métriques de qualité

| Métrique | Objectif | Critique |
|----------|----------|----------|
| Code Coverage | ≥ 80% | < 70% |
| Security Hotspots | 0 | > 5 |
| Critical Vulns | 0 | > 0 |
| High Vulns | < 5 | > 10 |
| Secrets | 0 | > 0 |

---

## 🛠️ Dépannage rapide

### Gitleaks : Faux positif

```toml
# Ajouter dans .gitleaks.toml
[allowlist]
paths = [
    '''tests/TestData\.json''',
]
regexes = [
    '''Server=\(localdb\)''',
]
```

### OWASP : Suppression temporaire

```xml
<!-- Ajouter dans .owasp-suppressions.xml -->
<suppress until="2024-06-30">
  <notes><![CDATA[
    Faux positif - Version correcte utilisée
    Reviewed: 2024-01-15
  ]]></notes>
  <packageUrl regex="true">^pkg:nuget/Package.*$</packageUrl>
  <cve>CVE-2024-12345</cve>
</suppress>
```

### Pipeline bloqué

```bash
# 1. Vérifier les logs
az pipelines runs show --id <run-id>

# 2. Re-run le stage qui a échoué
az pipelines run --id <run-id> --stage SecurityScanning

# 3. Bypass temporaire (DOCUMENTER!)
# Modifier azure-pipelines.yml : failOnVulnerabilities: false
```

---

## 📱 Commandes utiles

### Gitleaks

```bash
# Scanner tout
gitleaks detect --source . --verbose

# Scanner seulement staged files
gitleaks protect --staged

# Générer rapport JSON
gitleaks detect --report-path report.json --report-format json

# Utiliser config custom
gitleaks detect --config .gitleaks.toml
```

### Snyk

```bash
# Installer Snyk CLI
npm install -g snyk

# Authentifier
snyk auth

# Scanner .NET project
snyk test --all-projects

# Scanner avec seuil
snyk test --severity-threshold=high

# Monitor project (dashboard)
snyk monitor --project-name=MedSecure
```

### OWASP Dependency Check

```bash
# Scanner le projet
./dependency-check/bin/dependency-check.sh \
  --scan . \
  --format ALL \
  --out reports/ \
  --project MedSecure

# Avec suppressions
./dependency-check/bin/dependency-check.sh \
  --scan . \
  --suppression .owasp-suppressions.xml
```

### Trivy

```bash
# Scanner image Docker
trivy image medsecure/web:latest

# Scanner avec seuil
trivy image --severity CRITICAL,HIGH medsecure/web:latest

# Scanner filesystem
trivy fs .

# Scanner config (Dockerfile)
trivy config ./src/Web/Dockerfile

# Générer rapport JSON
trivy image --format json --output report.json medsecure/web:latest
```

### dotnet

```bash
# Lister les packages vulnérables
dotnet list package --vulnerable --include-transitive

# Mettre à jour un package
dotnet add package <PackageName> --version <Version>

# Audit de sécurité
dotnet restore --force-evaluate

# Générer rapport de dépendances
dotnet list package --include-transitive > dependencies.txt
```

---

## 🔗 Liens utiles

### Dashboards

- **SonarCloud** : https://sonarcloud.io/organizations/medsecure/projects
- **Snyk** : https://app.snyk.io
- **Azure DevOps** : https://dev.azure.com/medsecure
- **NVD Database** : https://nvd.nist.gov

### Documentation

- **Guide complet** : [DEVSECOPS_GUIDE.md](./DEVSECOPS_GUIDE.md)
- **HDS Compliance** : [HDS_COMPLIANCE_AUDIT.md](./HDS_COMPLIANCE_AUDIT.md)
- **CI Pipeline** : [CI_PIPELINE_GUIDE.md](./CI_PIPELINE_GUIDE.md)

### Standards

- **OWASP Top 10** : https://owasp.org/Top10
- **CWE Top 25** : https://cwe.mitre.org/top25
- **CVSS Calculator** : https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator

---

## ✅ Checklist avant commit

- [ ] Code compile sans erreurs
- [ ] Tests unitaires passent localement : `dotnet test`
- [ ] Gitleaks scan OK : `gitleaks protect --staged`
- [ ] Pas de secrets hardcodés
- [ ] Format de commit respecté : `type(scope): subject`
- [ ] Vulnérabilités corrigées : `snyk test`
- [ ] Code coverage ≥ 80%

---

## ✅ Checklist avant pull request

- [ ] Tous les tests passent
- [ ] Code coverage ≥ 80%
- [ ] Aucun secret détecté
- [ ] Aucune vulnérabilité Critical/High
- [ ] SonarCloud Quality Gate OK
- [ ] Description PR complète
- [ ] Tests fonctionnels documentés
- [ ] Migration guide (si applicable)

---

## 📞 Support

- **Incidents sécurité** : security@medsecure.fr
- **Questions DevOps** : devops@medsecure.fr
- **Documentation** : https://docs.medsecure.fr

---

**Version** : 1.0.0 | **Dernière mise à jour** : 2024-01-15
