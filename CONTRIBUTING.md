# 🤝 Guide de contribution - MedSecure Platform

Merci de votre intérêt pour contribuer à MedSecure ! Ce guide vous aidera à contribuer efficacement au projet.

---

## 📋 Table des matières

1. [Code de conduite](#code-de-conduite)
2. [Comment contribuer](#comment-contribuer)
3. [Workflow Git](#workflow-git)
4. [Standards de code](#standards-de-code)
5. [Tests](#tests)
6. [Documentation](#documentation)
7. [Sécurité](#sécurité)

---

## 📜 Code de conduite

### Nos engagements

- 🤝 Respecter tous les contributeurs
- 💬 Communiquer de manière constructive
- 🎯 Se concentrer sur ce qui est meilleur pour la communauté
- 🔒 Respecter la confidentialité des données de santé

### Comportements inacceptables

- ❌ Langage offensant ou discriminatoire
- ❌ Harcèlement sous toute forme
- ❌ Divulgation d'informations privées
- ❌ Conduite inappropriée en contexte professionnel

---

## 🚀 Comment contribuer

### Types de contributions

1. **🐛 Reporter un bug**
2. **💡 Suggérer une amélioration**
3. **📝 Améliorer la documentation**
4. **✨ Implémenter une nouvelle fonctionnalité**
5. **🔒 Corriger une vulnérabilité de sécurité**

### Avant de commencer

- [ ] Vérifier qu'une issue similaire n'existe pas déjà
- [ ] Lire le [Git Workflow](./docs/GIT_WORKFLOW.md)
- [ ] Configurer l'environnement local (voir [DEMARRAGE_LOCAL.md](./DEMARRAGE_LOCAL.md))
- [ ] Comprendre les [exigences HDS](#conformité-hds)

---

## 🌿 Workflow Git

### 1. Fork et clone

```bash
# Fork le repository sur GitHub/Azure DevOps

# Clone votre fork
git clone https://github.com/VOTRE-USERNAME/medsecure.git
cd medsecure

# Ajouter l'upstream
git remote add upstream https://github.com/medsecure/medsecure.git
```

### 2. Créer une branche

```bash
# Partir de develop à jour
git checkout develop
git pull upstream develop

# Créer votre branche
git checkout -b feature/ma-super-feature
```

### 3. Nommage des branches

| Type | Format | Exemple |
|------|--------|---------|
| Feature | `feature/US-XX-description` | `feature/US-09-patient-search` |
| Bugfix | `bugfix/description` | `bugfix/login-timeout` |
| Hotfix | `hotfix/description` | `hotfix/security-patch` |
| Security | `security/CVE-XXXX` | `security/CVE-2024-12345` |

### 4. Développer

```bash
# Faire vos changements
# Commiter régulièrement

git add .
git commit -m "feat(patients): add search by SSN"
```

### 5. Convention de commits

**Format** : `<type>(<scope>): <description>`

**Types** :
- `feat` - Nouvelle fonctionnalité
- `fix` - Correction de bug
- `security` - Patch de sécurité
- `perf` - Amélioration de performance
- `refactor` - Refactoring
- `docs` - Documentation
- `test` - Tests
- `chore` - Maintenance
- `ci` - CI/CD

**Exemples** :
```bash
git commit -m "feat(patients): add Always Encrypted for SSN"
git commit -m "fix(auth): resolve JWT token expiration"
git commit -m "security(sql): prevent SQL injection in search"
git commit -m "docs(readme): update deployment instructions"
```

### 6. Pousser et créer une Pull Request

```bash
# Pousser votre branche
git push -u origin feature/ma-super-feature

# Créer une Pull Request via l'interface web
```

---

## 💻 Standards de code

### C# / .NET

#### Style de code

```csharp
// ✅ BON
public class PatientService
{
    private readonly IPatientRepository _repository;
    private readonly ITelemetryService _telemetry;

    public PatientService(
        IPatientRepository repository,
        ITelemetryService telemetry)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _telemetry = telemetry ?? throw new ArgumentNullException(nameof(telemetry));
    }

    public async Task<Patient> GetByIdAsync(int id)
    {
        if (id <= 0)
            throw new ArgumentException("ID must be positive", nameof(id));

        var patient = await _repository.GetByIdAsync(id);

        if (patient == null)
            throw new PatientNotFoundException(id);

        return patient;
    }
}

// ❌ MAUVAIS
public class patientService  // Mauvais nommage
{
    IPatientRepository repo;  // Pas de private, pas de readonly

    public Patient GetById(int id)  // Pas async
    {
        return repo.GetById(id);  // Pas de validation, pas de null check
    }
}
```

#### Nommage

| Élément | Convention | Exemple |
|---------|------------|---------|
| Classes | PascalCase | `PatientService` |
| Méthodes | PascalCase | `GetPatientAsync` |
| Paramètres | camelCase | `patientId` |
| Champs privés | _camelCase | `_repository` |
| Propriétés | PascalCase | `FirstName` |
| Constantes | PascalCase | `MaxRetryCount` |
| Interfaces | IPascalCase | `IPatientRepository` |

#### Async/Await

```csharp
// ✅ BON
public async Task<Patient> GetPatientAsync(int id)
{
    return await _repository.GetByIdAsync(id);
}

// ❌ MAUVAIS
public Patient GetPatient(int id)  // Pas async
{
    return _repository.GetById(id).Result;  // .Result bloque
}
```

#### Gestion des erreurs

```csharp
// ✅ BON
public async Task<Patient> GetPatientAsync(int id)
{
    try
    {
        return await _repository.GetByIdAsync(id);
    }
    catch (NotFoundException ex)
    {
        _logger.LogWarning(ex, "Patient {PatientId} not found", id);
        throw;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to get patient {PatientId}", id);
        _telemetry.TrackException(ex);
        throw;
    }
}
```

#### XML Comments

```csharp
/// <summary>
/// Retrieves a patient by ID from the database.
/// </summary>
/// <param name="id">The unique patient identifier.</param>
/// <returns>The patient entity if found.</returns>
/// <exception cref="ArgumentException">Thrown when ID is invalid.</exception>
/// <exception cref="PatientNotFoundException">Thrown when patient not found.</exception>
public async Task<Patient> GetPatientAsync(int id)
{
    // Implementation
}
```

### Formatage automatique

```bash
# Formater tout le code
dotnet format

# Vérifier le formatage (CI/CD)
dotnet format --verify-no-changes
```

---

## 🧪 Tests

### Couverture requise

- **Minimum** : 80%
- **Objectif** : 90%+

### Types de tests

#### 1. Tests unitaires

```csharp
[Fact]
public async Task GetPatientAsync_WithValidId_ReturnsPatient()
{
    // Arrange
    var patientId = 1;
    var expected = new Patient { Id = patientId, FirstName = "John" };
    _mockRepository.Setup(r => r.GetByIdAsync(patientId))
        .ReturnsAsync(expected);

    // Act
    var result = await _service.GetPatientAsync(patientId);

    // Assert
    Assert.NotNull(result);
    Assert.Equal(expected.Id, result.Id);
    Assert.Equal(expected.FirstName, result.FirstName);
}

[Fact]
public async Task GetPatientAsync_WithInvalidId_ThrowsException()
{
    // Arrange
    var invalidId = -1;

    // Act & Assert
    await Assert.ThrowsAsync<ArgumentException>(
        () => _service.GetPatientAsync(invalidId)
    );
}
```

#### 2. Tests d'intégration

```csharp
public class PatientRepositoryIntegrationTests : IClassFixture<DatabaseFixture>
{
    [Fact]
    public async Task GetByIdAsync_WithExistingPatient_ReturnsPatient()
    {
        // Arrange
        using var context = _fixture.CreateContext();
        var repository = new PatientRepository(context);

        // Act
        var patient = await repository.GetByIdAsync(1);

        // Assert
        Assert.NotNull(patient);
    }
}
```

### Exécution des tests

```bash
# Tous les tests
dotnet test

# Tests unitaires uniquement
dotnet test --filter Category=Unit

# Tests d'intégration
dotnet test --filter Category=Integration

# Avec couverture de code
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
```

---

## 📝 Documentation

### Documentation requise

1. **Code** : XML comments sur classes et méthodes publiques
2. **README** : Instructions de démarrage et configuration
3. **Architecture** : Diagrammes et décisions techniques
4. **API** : Swagger/OpenAPI pour les endpoints
5. **Changelog** : Historique des versions

### Exemple de documentation

```csharp
/// <summary>
/// Service for managing patient records in compliance with HDS Article 6.1.
/// All patient data is encrypted at rest using TDE and Always Encrypted.
/// </summary>
/// <remarks>
/// This service implements:
/// - HDS Article 4.1: Audit trail for all patient data access
/// - HDS Article 6.1: Encryption of sensitive data
/// - RGPD Article 9: Special category data protection
/// </remarks>
public class PatientService : IPatientService
{
    // Implementation
}
```

---

## 🔒 Sécurité

### Conformité HDS OBLIGATOIRE

Toute contribution manipulant des données de santé DOIT respecter :

#### 1. Données sensibles

```csharp
// ✅ BON - Always Encrypted
[Column(TypeName = "nvarchar(100)")]
public string FirstName { get; set; }  // Chiffré en base

// ❌ MAUVAIS
public string SocialSecurityNumber { get; set; }  // En clair !
```

#### 2. Audit trail

```csharp
// ✅ BON - Track access
public async Task<Patient> GetPatientAsync(int id)
{
    _telemetry.TrackPatientAccess(
        patientId: id.ToString(),
        action: "Read",
        userId: _httpContext.User.Identity.Name
    );

    return await _repository.GetByIdAsync(id);
}
```

#### 3. Validation des entrées

```csharp
// ✅ BON
public async Task<Patient> CreatePatientAsync(PatientDto dto)
{
    // Validation
    if (string.IsNullOrWhiteSpace(dto.FirstName))
        throw new ValidationException("FirstName is required");

    // Sanitization
    dto.FirstName = _sanitizer.Sanitize(dto.FirstName);

    // SQL injection prevention (EF Core parameterized queries)
    var patient = _mapper.Map<Patient>(dto);
    return await _repository.AddAsync(patient);
}
```

#### 4. Pas de secrets hardcodés

```csharp
// ❌ MAUVAIS
const string ApiKey = "sk-1234567890abcdef";

// ✅ BON
var apiKey = _configuration["ApiKey"];
// OU
var apiKey = await _keyVaultClient.GetSecretAsync("ApiKey");
```

### Reporter une vulnérabilité

**NE PAS** créer une issue publique !

1. Envoyer un email à : security@medsecure.health
2. Inclure :
   - Description de la vulnérabilité
   - Impact potentiel
   - Étapes pour reproduire
   - Suggestion de correction (si possible)

---

## ✅ Checklist avant de soumettre

### Code

- [ ] Code compilé sans erreurs ni warnings
- [ ] Formaté avec `dotnet format`
- [ ] Pas de code commenté inutile
- [ ] Pas de `TODO` ou `FIXME` non résolus
- [ ] Nommage clair et cohérent

### Tests

- [ ] Tests unitaires écrits
- [ ] Tous les tests passent
- [ ] Couverture de code >= 80%
- [ ] Edge cases testés

### Sécurité (HDS)

- [ ] Pas de données sensibles en clair
- [ ] Validation des entrées
- [ ] Audit trail si accès données de santé
- [ ] Scan Gitleaks OK (pas de secrets)

### Documentation

- [ ] XML comments ajoutés
- [ ] README mis à jour si nécessaire
- [ ] CHANGELOG.md mis à jour

### Git

- [ ] Branche à jour avec `develop`
- [ ] Commits suivent Conventional Commits
- [ ] Message de commit descriptif
- [ ] Pas de merge commits

---

## 🎓 Ressources

### Documentation interne

- [Git Workflow](./docs/GIT_WORKFLOW.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Guide Application Insights](./docs/APPLICATION_INSIGHTS_GUIDE.md)
- [Guide Chiffrement](./docs/ENCRYPTION_TDE_ALWAYS_ENCRYPTED_GUIDE.md)

### Standards et conformité

- [HDS Référentiel](https://esante.gouv.fr/labels-certifications/hds)
- [RGPD](https://www.cnil.fr/fr/reglement-europeen-protection-donnees)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

### Outils

- [SonarCloud](https://sonarcloud.io/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [dotnet format](https://github.com/dotnet/format)

---

## 💬 Besoin d'aide ?

- 💬 Discussions : [GitHub Discussions](https://github.com/medsecure/medsecure/discussions)
- 🐛 Bugs : [GitHub Issues](https://github.com/medsecure/medsecure/issues)
- 📧 Email : dev@medsecure.health
- 📖 Documentation : [Wiki](https://github.com/medsecure/medsecure/wiki)

---

## 🙏 Merci !

Merci de contribuer à MedSecure et d'aider à améliorer la sécurité des données de santé !

Chaque contribution, petite ou grande, fait la différence. 🎉

---

**Dernière mise à jour** : 2026-02-09
**Version** : 1.0.0
