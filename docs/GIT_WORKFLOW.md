# 🌿 Git Workflow - MedSecure Platform

## Vue d'ensemble

MedSecure utilise une stratégie de branching **GitHub Flow modifiée** adaptée pour un environnement de santé réglementé (HDS).

Cette stratégie équilibre :
- ✅ Agilité du développement
- ✅ Conformité réglementaire (HDS, RGPD)
- ✅ Sécurité et traçabilité
- ✅ Déploiements fiables

---

## 📊 Stratégie de branching

### Structure des branches

```
main (production) ─────────────────────────────────────────────►
     │                    │                    │
     └─► release/v1.0 ────┴─► hotfix/fix-xxx ─┘
          │
          └─► develop ──────────────────────────────────────────►
               │         │         │         │
               ├─► feature/US-01-infrastructure
               ├─► feature/US-02-ci-cd
               ├─► bugfix/fix-patient-form
               └─► security/CVE-2024-xxxxx
```

### Branches principales

| Branche | Description | Protection | Déploiement |
|---------|-------------|------------|-------------|
| **main** | Production stable | ✅ Protégée | Production automatique |
| **develop** | Intégration continue | ✅ Protégée | DEV automatique |
| **release/vX.Y** | Préparation release | ✅ Protégée | STAGING automatique |

### Branches de travail

| Préfixe | Usage | Exemple | Durée de vie |
|---------|-------|---------|--------------|
| **feature/** | Nouvelles fonctionnalités | `feature/US-05-keyvault` | Court (1-5 jours) |
| **bugfix/** | Corrections de bugs | `bugfix/patient-validation` | Court (1-2 jours) |
| **hotfix/** | Corrections urgentes production | `hotfix/security-patch` | Très court (<1 jour) |
| **security/** | Patches de sécurité | `security/CVE-2024-12345` | Très court (<1 jour) |
| **refactor/** | Refactoring code | `refactor/cleanup-services` | Moyen (3-7 jours) |
| **docs/** | Documentation uniquement | `docs/update-readme` | Court (1-2 jours) |

---

## 🔄 Flux de travail standard

### 1. Développer une nouvelle fonctionnalité

```bash
# 1. Partir de develop à jour
git checkout develop
git pull origin develop

# 2. Créer une branche feature
git checkout -b feature/US-08-appinsights

# 3. Développer et commiter régulièrement
git add .
git commit -m "feat(monitoring): add Application Insights configuration"

# 4. Pousser la branche
git push -u origin feature/US-08-appinsights

# 5. Créer une Pull Request vers develop
# Via GitHub/Azure DevOps UI
```

### 2. Corriger un bug

```bash
# 1. Partir de develop
git checkout develop
git pull origin develop

# 2. Créer une branche bugfix
git checkout -b bugfix/patient-form-validation

# 3. Corriger et tester
git add .
git commit -m "fix(patients): validate SSN format before save"

# 4. Pousser et créer une PR
git push -u origin bugfix/patient-form-validation
```

### 3. Hotfix en production (URGENT)

```bash
# 1. Partir de main (production actuelle)
git checkout main
git pull origin main

# 2. Créer une branche hotfix
git checkout -b hotfix/security-vulnerability

# 3. Corriger rapidement
git add .
git commit -m "security: patch SQL injection vulnerability"

# 4. Pousser
git push -u origin hotfix/security-vulnerability

# 5. Créer 2 Pull Requests :
#    - PR 1: hotfix → main (déploiement production)
#    - PR 2: hotfix → develop (intégration future)
```

### 4. Préparer une release

```bash
# 1. Partir de develop
git checkout develop
git pull origin develop

# 2. Créer une branche release
git checkout -b release/v1.2.0

# 3. Finaliser (version, changelog, tests)
git add .
git commit -m "chore(release): prepare v1.2.0"

# 4. Pousser
git push -u origin release/v1.2.0

# 5. Tester en STAGING (déploiement automatique)

# 6. Créer PR vers main pour production
# 7. Après merge, merger aussi dans develop
```

---

## 📝 Convention de commits (Conventional Commits)

### Format

```
<type>(<scope>): <description>

[corps optionnel]

[footer optionnel]
```

### Types de commits

| Type | Description | Exemple |
|------|-------------|---------|
| **feat** | Nouvelle fonctionnalité | `feat(patients): add medical record search` |
| **fix** | Correction de bug | `fix(auth): resolve login timeout issue` |
| **security** | Patch de sécurité | `security(sql): prevent SQL injection in search` |
| **perf** | Amélioration de performance | `perf(db): optimize patient query with index` |
| **refactor** | Refactoring (pas de changement fonctionnel) | `refactor(services): extract telemetry service` |
| **docs** | Documentation uniquement | `docs(readme): update deployment instructions` |
| **test** | Ajout ou modification de tests | `test(patients): add unit tests for validation` |
| **chore** | Tâches de maintenance | `chore(deps): update NuGet packages` |
| **ci** | Modifications CI/CD | `ci(pipeline): add SonarCloud integration` |
| **style** | Formatage, style (pas de changement de code) | `style(web): format with dotnet-format` |

### Scopes communs

- `patients` - Gestion des patients
- `records` - Dossiers médicaux
- `auth` - Authentification/autorisation
- `monitoring` - Application Insights, logs
- `security` - Sécurité, chiffrement
- `infra` - Infrastructure (Bicep)
- `pipeline` - CI/CD
- `db` - Base de données

### Exemples de bons commits

```bash
# Feature
git commit -m "feat(patients): add Always Encrypted for SSN column"

# Fix avec référence issue
git commit -m "fix(auth): resolve token expiration bug

Fixes #123

The JWT token was expiring prematurely due to incorrect timezone
handling. This commit fixes the issue by using UTC consistently."

# Security avec footer
git commit -m "security(api): patch SQL injection vulnerability

BREAKING CHANGE: API endpoint /api/patients now requires authentication

CVE-2024-12345
Reviewed-by: Security Team"

# Chore simple
git commit -m "chore(deps): upgrade Entity Framework to 8.0.2"
```

---

## 🛡️ Protection des branches

### Configuration requise

**Branch: main**
```yaml
Protection:
  - Require pull request reviews: 2 approvals
  - Require status checks to pass: true
  - Required checks:
      - build-and-test
      - sonarcloud-analysis
      - security-scan
      - dependency-check
  - Require branches to be up to date: true
  - Require conversation resolution: true
  - Require signed commits: true (recommandé)
  - Include administrators: true
  - Restrict who can push: Release Managers only
  - Allow force pushes: false
  - Allow deletions: false
```

**Branch: develop**
```yaml
Protection:
  - Require pull request reviews: 1 approval
  - Require status checks to pass: true
  - Required checks:
      - build-and-test
      - sonarcloud-analysis
  - Require branches to be up to date: true
  - Require conversation resolution: true
  - Allow force pushes: false
  - Allow deletions: false
```

**Branch: release/**
```yaml
Protection:
  - Require pull request reviews: 2 approvals
  - Require status checks to pass: true
  - Required checks:
      - build-and-test
      - sonarcloud-analysis
      - security-scan
      - integration-tests
  - Require branches to be up to date: true
  - Require signed commits: true (recommandé)
  - Allow force pushes: false
```

---

## 🔍 Code Review - Checklist

### Pour l'auteur (avant de créer la PR)

- [ ] Code compilé sans erreurs ni warnings
- [ ] Tests unitaires écrits et passent
- [ ] Code formaté avec `dotnet format`
- [ ] Pas de secrets hardcodés (vérifier avec Gitleaks)
- [ ] Documentation mise à jour (README, XML comments)
- [ ] Changelog mis à jour (pour features importantes)
- [ ] Description de la PR complète et claire
- [ ] Branche à jour avec la branche cible
- [ ] Auto-review effectuée

### Pour le reviewer

**Fonctionnel**
- [ ] Le code fait ce qu'il est censé faire
- [ ] Pas de régression introduite
- [ ] Edge cases gérés
- [ ] Validation des entrées appropriée

**Sécurité** (CRITIQUE pour HDS)
- [ ] Pas de SQL injection possible
- [ ] Pas de XSS possible
- [ ] Authentification/autorisation correcte
- [ ] Données sensibles chiffrées
- [ ] Pas de secrets exposés
- [ ] Logging approprié (sans données sensibles)

**Performance**
- [ ] Pas de N+1 queries
- [ ] Index de base de données appropriés
- [ ] Pas de boucles inefficaces
- [ ] Utilisation de async/await appropriée

**Qualité de code**
- [ ] Code lisible et maintenable
- [ ] Nommage clair et cohérent
- [ ] Pas de duplication
- [ ] SOLID principles respectés
- [ ] Tests adéquats

**Compliance HDS**
- [ ] Audit trail si accès aux données de santé
- [ ] Chiffrement si données sensibles
- [ ] Logs de sécurité appropriés

---

## 🤝 Pull Request Template

### Template par défaut

```markdown
## Description
<!-- Décrivez clairement les changements et leur raison d'être -->

## Type de changement
- [ ] Feature (nouvelle fonctionnalité)
- [ ] Bugfix (correction de bug)
- [ ] Hotfix (correction urgente production)
- [ ] Security (patch de sécurité)
- [ ] Refactoring
- [ ] Documentation
- [ ] Performance

## User Story / Issue
Closes #[numéro]
Related to #[numéro]

## Changements effectués
-
-
-

## Tests effectués
- [ ] Tests unitaires ajoutés/modifiés
- [ ] Tests d'intégration passent
- [ ] Tests manuels effectués
- [ ] Testé en environnement local

## Checklist sécurité (HDS)
- [ ] Pas de données sensibles en clair
- [ ] Chiffrement approprié si nécessaire
- [ ] Audit trail si accès aux données de santé
- [ ] Validation des entrées
- [ ] Pas de secrets hardcodés

## Screenshots / Logs
<!-- Si applicable, ajoutez des captures d'écran ou logs -->

## Impact
- [ ] Breaking change (nécessite migration)
- [ ] Modification de base de données (migration requise)
- [ ] Modification de configuration (appsettings)
- [ ] Impact sur les performances

## Documentation
- [ ] README mis à jour
- [ ] Documentation technique mise à jour
- [ ] XML comments ajoutés/mis à jour
- [ ] CHANGELOG.md mis à jour

## Reviewers
@security-team (si changement sécurité)
@devops-team (si changement infrastructure/pipeline)

## Notes additionnelles
<!-- Informations supplémentaires pour les reviewers -->
```

---

## 🚀 Déploiement automatique

### Déclencheurs de déploiement

| Branche | Environnement | Déclencheur | Approbation |
|---------|---------------|-------------|-------------|
| `feature/*` | - | Aucun | N/A |
| `develop` | DEV | Push/Merge | Automatique |
| `release/*` | STAGING | Push/Merge | Automatique |
| `main` | PRODUCTION | Merge PR | Manuelle (2 approvals) |
| `hotfix/*` | - | Aucun | N/A |

### Pipeline déclenchée par branche

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop
      - release/*
  paths:
    exclude:
      - docs/**
      - README.md
      - .gitignore

pr:
  branches:
    include:
      - main
      - develop
  paths:
    exclude:
      - docs/**
```

---

## 🔒 Git Hooks (local)

### Pre-commit hook

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running pre-commit checks..."

# 1. Format code
dotnet format --verify-no-changes
if [ $? -ne 0 ]; then
    echo "❌ Code formatting issues detected. Run 'dotnet format' to fix."
    exit 1
fi

# 2. Check for secrets
gitleaks detect --no-git --verbose
if [ $? -ne 0 ]; then
    echo "❌ Secrets detected! Remove them before committing."
    exit 1
fi

# 3. Run unit tests
dotnet test --filter "Category=Unit" --no-build
if [ $? -ne 0 ]; then
    echo "❌ Unit tests failed!"
    exit 1
fi

echo "✅ Pre-commit checks passed!"
exit 0
```

### Commit-msg hook

```bash
#!/bin/sh
# .git/hooks/commit-msg

commit_msg=$(cat "$1")

# Validate commit message format (Conventional Commits)
if ! echo "$commit_msg" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore|ci|security)\([a-z-]+\): .{1,100}$'; then
    echo "❌ Invalid commit message format!"
    echo "Expected: <type>(<scope>): <description>"
    echo "Example: feat(patients): add medical record search"
    exit 1
fi

echo "✅ Commit message format valid"
exit 0
```

---

## 📦 Release Process

### 1. Planification

```bash
# Créer un milestone sur GitHub/Azure DevOps
# Assigner les issues/PR au milestone
```

### 2. Préparation

```bash
# Créer la branche release
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# Mettre à jour la version
# Dans Directory.Build.props ou AssemblyInfo
<Version>1.2.0</Version>

# Générer le changelog
git log v1.1.0..HEAD --pretty=format:"%s" > CHANGELOG_v1.2.0.md

# Commit
git add .
git commit -m "chore(release): prepare v1.2.0"
git push -u origin release/v1.2.0
```

### 3. Tests en STAGING

- Déploiement automatique vers STAGING
- Tests d'intégration
- Tests de charge
- Tests de sécurité (penetration testing)
- Validation HDS

### 4. Merge vers production

```bash
# 1. Créer PR: release/v1.2.0 → main
# 2. Approbation par 2 reviewers
# 3. Merge (avec merge commit, pas de squash)

# 4. Tag la version
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# 5. Merger aussi dans develop
git checkout develop
git merge main
git push origin develop
```

### 5. Post-release

- Fermer le milestone
- Publier les release notes
- Mettre à jour la documentation
- Archiver la branche release (optionnel)

---

## 🆘 Scénarios courants

### Annuler un commit (pas encore poussé)

```bash
# Annuler le dernier commit (garde les changements)
git reset --soft HEAD~1

# Annuler le dernier commit (jette les changements)
git reset --hard HEAD~1
```

### Corriger le message du dernier commit

```bash
git commit --amend -m "nouveau message"
```

### Récupérer une branche supprimée

```bash
# Trouver le SHA du dernier commit
git reflog

# Recréer la branche
git checkout -b ma-branche-recuperee <SHA>
```

### Résoudre un conflit

```bash
# 1. Mettre à jour la branche cible
git checkout develop
git pull origin develop

# 2. Rebaser votre branche
git checkout feature/ma-feature
git rebase develop

# 3. Résoudre les conflits dans l'éditeur

# 4. Continuer le rebase
git add .
git rebase --continue

# 5. Forcer le push (attention !)
git push --force-with-lease origin feature/ma-feature
```

### Synchroniser une fork

```bash
# Ajouter l'upstream (une seule fois)
git remote add upstream https://github.com/original/repo.git

# Synchroniser
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## 📊 Métriques Git

### Métriques à suivre

- **Cycle time** : Temps entre création et merge d'une PR
- **Code review time** : Temps de review d'une PR
- **PR size** : Nombre de lignes modifiées par PR (idéal < 500)
- **Merge frequency** : Nombre de merges vers develop/main par jour
- **Hotfix frequency** : Nombre de hotfixes (objectif: minimiser)

### Objectifs

| Métrique | Objectif | Limite max |
|----------|----------|------------|
| Cycle time | < 2 jours | 5 jours |
| Code review time | < 4 heures | 24 heures |
| PR size | < 300 lignes | 500 lignes |
| Merge frequency | > 5/jour | - |
| Hotfix frequency | < 1/semaine | 2/semaine |

---

## ✅ Checklist de configuration

### Configuration initiale du repository

- [ ] Créer les branches `main` et `develop`
- [ ] Configurer les protections de branches
- [ ] Ajouter le template de Pull Request
- [ ] Configurer les hooks Git locaux
- [ ] Créer les labels (feature, bugfix, security, etc.)
- [ ] Configurer les notifications (Slack, Teams)
- [ ] Documenter le workflow dans README.md
- [ ] Former l'équipe au workflow

### Configuration des développeurs

- [ ] Cloner le repository
- [ ] Installer les hooks Git
- [ ] Configurer Git (nom, email, GPG signing)
- [ ] Installer les outils (dotnet format, gitleaks)
- [ ] Lire et comprendre le workflow

---

## 🔗 Ressources

### Documentation

- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Semantic Versioning](https://semver.org/)

### Outils

- [Gitleaks](https://github.com/gitleaks/gitleaks) - Détection de secrets
- [Commitlint](https://commitlint.js.org/) - Validation des commits
- [Husky](https://typicode.github.io/husky/) - Git hooks
- [dotnet-format](https://github.com/dotnet/format) - Formatage C#

---

**Date de création** : 2026-02-09
**Version** : 1.0.0
**Auteur** : DevSecOps Team - MedSecure Platform
