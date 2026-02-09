# Guide Pipeline CI/CD - MedSecure

## 📋 Vue d'ensemble

Pipeline Azure DevOps complet pour MedSecure avec :
- ✅ Build .NET 8 automatisé
- ✅ Tests (unitaires + intégration + fonctionnels)
- ✅ Code coverage > 80%
- ✅ Docker build multi-stage
- ✅ Déploiement multi-environnements (DEV → STAGING → PROD)

---

## 🚀 Configuration initiale

### 1. Créer le projet Azure DevOps

```bash
# Créer une organization (si nécessaire)
az devops configure --defaults organization=https://dev.azure.com/your-org

# Créer un projet
az devops project create \
  --name "MedSecure" \
  --description "HealthTech platform - HDS compliant" \
  --visibility private

# Configurer le projet par défaut
az devops configure --defaults project=MedSecure
```

### 2. Importer le repository Git

```bash
# Option 1: Importer depuis GitHub
az repos import create \
  --git-url https://github.com/your-org/medsecure.git \
  --repository medsecure

# Option 2: Push vers Azure Repos
git remote add azure https://dev.azure.com/your-org/MedSecure/_git/medsecure
git push azure main
```

### 3. Créer le pipeline

```bash
# Créer le pipeline depuis azure-pipelines.yml
az pipelines create \
  --name "MedSecure-CI" \
  --repository medsecure \
  --repository-type tfsgit \
  --branch main \
  --yml-path azure-pipelines.yml
```

---

## 🔧 Configuration des variables

### Variables de pipeline

#### Dans Azure DevOps UI :
**Pipelines → Library → Variable groups**

Créer un groupe de variables `medsecure-ci` :

| Variable | Valeur | Secret | Description |
|----------|--------|--------|-------------|
| `buildConfiguration` | `Release` | Non | Configuration build |
| `dotnetSdkVersion` | `8.x` | Non | Version .NET SDK |
| `coverageThreshold` | `80` | Non | Seuil coverage minimum |

#### Via Azure CLI :

```bash
# Créer un variable group
az pipelines variable-group create \
  --name "medsecure-ci" \
  --variables \
    buildConfiguration=Release \
    dotnetSdkVersion=8.x \
    coverageThreshold=80
```

---

## 📊 Stages du pipeline

### Stage 1: Build & Test

**Triggers :**
- Push sur `main`, `develop`, `feature/*`, `hotfix/*`
- Pull Request vers `main` ou `develop`

**Actions :**
1. Install .NET SDK 8.x
2. Restore NuGet packages
3. Build solution (Release)
4. Run Unit Tests + Code Coverage
5. Run Integration Tests
6. Run Functional Tests
7. Publish Test Results
8. Verify Coverage > 80%
9. Publish artifacts

**Durée estimée :** 5-10 minutes

**Artefacts produits :**
- `medsecure-drop` : Application publiée (.zip)
- `infra` : Templates Bicep
- `CodeCoverage` : Rapports de coverage

### Stage 2: Code Quality

**Dépend de :** Build

**Actions :**
- ⚠️ SonarCloud analysis (à configurer en US-03)

**Durée estimée :** 3-5 minutes

### Stage 3: Docker Build & Scan

**Dépend de :** Build

**Condition :** Uniquement sur branche `main`

**Actions :**
1. Build Docker image multi-stage
2. Tag image (BuildId + latest)
3. ⚠️ Scan Trivy (à configurer en US-03)
4. ⚠️ Push vers ACR (à configurer en US-04)

**Durée estimée :** 5-10 minutes

### Stage 4: Deploy to DEV

**Dépend de :** Build + Docker

**Condition :** Branche `develop` uniquement

**Actions :**
- ⚠️ Déploiement automatique sur DEV (à configurer en US-04)

**Durée estimée :** 2-5 minutes

### Stage 5: Deploy to STAGING

**Dépend de :** Build + Docker + CodeQuality

**Condition :** Branche `main` uniquement

**Approbation :** Manuelle (environnement Azure DevOps)

**Actions :**
- ⚠️ Déploiement Blue/Green sur STAGING (à configurer en US-04)

**Durée estimée :** 2-5 minutes

### Stage 6: Deploy to PRODUCTION

**Dépend de :** Deploy STAGING

**Approbation :** Manuelle + 2 approbateurs minimum

**Actions :**
- ⚠️ Déploiement Blue/Green sur PRODUCTION (à configurer en US-04)

**Durée estimée :** 2-5 minutes

---

## 🧪 Tests et Code Coverage

### Configuration des tests

Le pipeline exécute 3 types de tests :

#### 1. Unit Tests

**Projet :** `tests/UnitTests/*.csproj`

**Configuration :**
```xml
<!-- tests/UnitTests/UnitTests.csproj -->
<ItemGroup>
  <PackageReference Include="xunit" Version="2.6.6" />
  <PackageReference Include="xunit.runner.visualstudio" Version="2.5.6" />
  <PackageReference Include="coverlet.collector" Version="6.0.0" />
  <PackageReference Include="Moq" Version="4.20.70" />
  <PackageReference Include="FluentAssertions" Version="6.12.0" />
</ItemGroup>
```

**Exemple de test :**
```csharp
public class CatalogServiceTests
{
    [Fact]
    public async Task GetCatalogItems_ReturnsItems()
    {
        // Arrange
        var mockRepo = new Mock<IRepository<CatalogItem>>();
        var service = new CatalogService(mockRepo.Object);

        // Act
        var result = await service.GetCatalogItemsAsync();

        // Assert
        result.Should().NotBeNull();
    }
}
```

#### 2. Integration Tests

**Projet :** `tests/IntegrationTests/*.csproj`

**Configuration :**
```xml
<ItemGroup>
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.0" />
  <PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="8.0.0" />
</ItemGroup>
```

**Exemple de test :**
```csharp
public class CatalogControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public CatalogControllerTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Get_ReturnsSuccessAndCorrectContentType()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/catalog");

        // Assert
        response.EnsureSuccessStatusCode();
        Assert.Equal("application/json; charset=utf-8",
            response.Content.Headers.ContentType?.ToString());
    }
}
```

#### 3. Functional Tests

**Projet :** `tests/FunctionalTests/*.csproj`

**Configuration :**
```xml
<ItemGroup>
  <PackageReference Include="Selenium.WebDriver" Version="4.17.0" />
  <PackageReference Include="Microsoft.Playwright" Version="1.41.0" />
</ItemGroup>
```

### Code Coverage

**Outil :** Coverlet + ReportGenerator

**Seuil minimum :** 80%

**Exclusions :**
- Migrations EF Core
- Program.cs / Startup.cs
- ViewModels (DTO)

**Configuration :**
```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <CoverletOutput>$(OutputPath)coverage.json</CoverletOutput>
  <CoverletOutputFormat>cobertura</CoverletOutputFormat>
  <Exclude>[*]*.Migrations.*</Exclude>
  <ExcludeByAttribute>Obsolete,GeneratedCode,CompilerGenerated</ExcludeByAttribute>
</PropertyGroup>
```

**Vérification locale :**
```bash
# Exécuter les tests avec coverage
dotnet test --collect:"XPlat Code Coverage"

# Générer le rapport HTML
reportgenerator \
  -reports:**/coverage.cobertura.xml \
  -targetdir:./coverage-report \
  -reporttypes:Html

# Ouvrir le rapport
open coverage-report/index.html
```

---

## 🐳 Docker Build

### Build local

```bash
# Build l'image
docker build \
  --build-arg BUILD_CONFIGURATION=Release \
  --build-arg BUILD_VERSION=1.0.0 \
  -t medsecure/web:latest \
  -f src/Web/Dockerfile \
  .

# Run localement
docker run -d \
  --name medsecure-web \
  -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Development \
  medsecure/web:latest

# Tester le health check
curl http://localhost:8080/health

# Voir les logs
docker logs medsecure-web

# Arrêter et supprimer
docker stop medsecure-web
docker rm medsecure-web
```

### Optimisations Docker

**Layer caching :**
1. Copy project files first
2. Restore dependencies
3. Copy source code
4. Build

**Multi-stage build :**
- Stage 1: Build (SDK 8.0) ~800MB
- Stage 2: Publish (optimized)
- Stage 3: Runtime (ASP.NET 8.0) ~200MB

**Résultat final :** Image ~220MB (vs ~800MB sans multi-stage)

---

## 📈 Monitoring du pipeline

### Métriques importantes

| Métrique | Objectif | Alerte |
|----------|----------|--------|
| **Build success rate** | 100% | < 95% |
| **Avg build time** | < 10 min | > 15 min |
| **Test success rate** | > 98% | < 95% |
| **Code coverage** | > 80% | < 70% |
| **Deployment frequency** | Daily | Weekly |

### Tableau de bord

**Azure DevOps → Pipelines → Analytics**

Widgets à ajouter :
- ✅ Pass rate trend
- ✅ Duration trend
- ✅ Test results trend
- ✅ Code coverage trend
- ✅ Deployment frequency

---

## 🚨 Troubleshooting

### Erreur: "Build failed with exit code 1"

**Cause :** Erreur de compilation .NET

**Solution :**
```bash
# Build local pour voir l'erreur
dotnet build --configuration Release

# Vérifier les warnings
dotnet build --configuration Release /warnaserror
```

### Erreur: "Tests failed"

**Cause :** Tests en échec

**Solution :**
```bash
# Exécuter les tests localement
dotnet test --logger "console;verbosity=detailed"

# Run un test spécifique
dotnet test --filter "FullyQualifiedName~CatalogServiceTests"
```

### Erreur: "Code coverage below threshold"

**Cause :** Coverage < 80%

**Solution :**
```bash
# Voir quelles classes manquent de tests
dotnet test --collect:"XPlat Code Coverage"
reportgenerator -reports:**/coverage.cobertura.xml -targetdir:./coverage

# Ajouter des tests pour les classes non couvertes
```

### Erreur: "Docker build failed"

**Cause :** Erreur dans Dockerfile ou contexte trop grand

**Solution :**
```bash
# Vérifier le contexte Docker
docker build --no-cache -t test -f src/Web/Dockerfile .

# Vérifier la taille du contexte
du -sh .

# Nettoyer le contexte (vérifier .dockerignore)
```

---

## ✅ Checklist avant merge

### Développeur

- [ ] Tests passent localement (`dotnet test`)
- [ ] Coverage > 80% (`dotnet test --collect:"XPlat Code Coverage"`)
- [ ] Build Docker réussit (`docker build ...`)
- [ ] Aucun warning de compilation
- [ ] Code formaté (`.editorconfig`)

### Pull Request

- [ ] Pipeline CI vert (all stages passed)
- [ ] 2 reviewers approuvé
- [ ] Tous les commentaires résolus
- [ ] Lien avec Work Item Azure Boards
- [ ] Branch à jour avec `main`

### Production

- [ ] Tests staging validés
- [ ] Documentation à jour
- [ ] Changelog mis à jour
- [ ] Rollback plan documenté

---

## 📚 Ressources

- [Azure Pipelines YAML Schema](https://learn.microsoft.com/azure/devops/pipelines/yaml-schema)
- [.NET Core testing](https://learn.microsoft.com/dotnet/core/testing/)
- [Coverlet documentation](https://github.com/coverlet-coverage/coverlet)
- [Docker best practices](https://docs.docker.com/develop/dev-best-practices/)

---

## 🔄 Prochaines étapes (US-03, US-04)

### US-03 : DevSecOps
- [ ] Intégrer SonarCloud
- [ ] Ajouter Gitleaks (pre-commit)
- [ ] Configurer Snyk
- [ ] Ajouter OWASP Dependency Check
- [ ] Scan Trivy pour Docker

### US-04 : CD Blue/Green
- [ ] Créer pipeline CD
- [ ] Configurer environments Azure DevOps
- [ ] Implémenter Blue/Green deployment
- [ ] Smoke tests post-deployment
- [ ] Rollback automatique

---

**Version :** 1.0
**Date :** 09/02/2026
**Auteur :** DevSecOps Team MedSecure
