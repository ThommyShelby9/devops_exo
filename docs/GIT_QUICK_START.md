# 🚀 Git Quick Start - MedSecure

Guide de démarrage rapide pour travailler avec Git sur le projet MedSecure.

---

## ⚡ Configuration initiale (une seule fois)

```bash
# 1. Cloner le repository
git clone https://github.com/medsecure/medsecure.git
cd medsecure

# 2. Configurer votre identité
git config user.name "Votre Nom"
git config user.email "votre.email@exemple.com"

# 3. Installer les hooks Git (important !)
pwsh ./Setup-GitHooks.ps1

# 4. Créer la branche develop si elle n'existe pas
git checkout -b develop
git push -u origin develop
```

---

## 📝 Workflow quotidien

### Commencer une nouvelle fonctionnalité

```bash
# 1. Partir de develop à jour
git checkout develop
git pull origin develop

# 2. Créer votre branche
git checkout -b feature/US-XX-description

# 3. Travailler et commiter
git add .
git commit -m "feat(scope): description de votre changement"

# 4. Pousser vers GitHub/Azure DevOps
git push -u origin feature/US-XX-description

# 5. Créer une Pull Request via l'interface web
```

### Corriger un bug

```bash
# Partir de develop
git checkout develop
git pull origin develop

# Créer branche bugfix
git checkout -b bugfix/description-du-bug

# Corriger, commiter, pousser
git add .
git commit -m "fix(scope): correction du bug"
git push -u origin bugfix/description-du-bug
```

### Hotfix urgent en production

```bash
# Partir de main
git checkout main
git pull origin main

# Créer branche hotfix
git checkout -b hotfix/correction-urgente

# Corriger rapidement
git add .
git commit -m "fix(critical): correction urgente production"
git push -u origin hotfix/correction-urgente

# Créer 2 PR : hotfix → main ET hotfix → develop
```

---

## 💬 Messages de commit

### Format : `<type>(<scope>): <description>`

### Types courants

| Type | Utilisation | Exemple |
|------|-------------|---------|
| `feat` | Nouvelle fonctionnalité | `feat(patients): add search feature` |
| `fix` | Correction de bug | `fix(auth): resolve login timeout` |
| `security` | Patch sécurité | `security(sql): prevent injection` |
| `docs` | Documentation | `docs(readme): update setup guide` |
| `test` | Tests | `test(patients): add unit tests` |
| `refactor` | Refactoring | `refactor(services): extract common logic` |
| `perf` | Performance | `perf(db): add index on patient search` |
| `chore` | Maintenance | `chore(deps): update packages` |

### Exemples complets

```bash
# Feature simple
git commit -m "feat(patients): add Always Encrypted for SSN column"

# Fix avec description longue
git commit -m "fix(auth): resolve JWT token expiration issue

The token was expiring prematurely due to timezone handling.
Now using UTC consistently throughout the application.

Fixes #123"

# Security patch critique
git commit -m "security(api): patch SQL injection vulnerability

BREAKING CHANGE: API endpoint requires authentication

CVE-2024-12345
Reviewed-by: Security Team"
```

---

## 🔄 Commandes utiles

### Synchronisation

```bash
# Mettre à jour votre branche locale
git pull origin develop

# Pousser vos changements
git push origin feature/ma-feature

# Récupérer toutes les branches
git fetch --all
```

### Statut et historique

```bash
# Voir l'état actuel
git status

# Voir l'historique des commits
git log --oneline --graph --all --decorate

# Voir les changements non stagés
git diff

# Voir les changements stagés
git diff --staged
```

### Branches

```bash
# Lister toutes les branches
git branch -a

# Changer de branche
git checkout develop

# Créer et basculer sur une nouvelle branche
git checkout -b feature/ma-nouvelle-feature

# Supprimer une branche locale
git branch -d feature/ancienne-feature

# Supprimer une branche remote
git push origin --delete feature/ancienne-feature
```

### Annulations

```bash
# Annuler le dernier commit (garder les changements)
git reset --soft HEAD~1

# Annuler les changements d'un fichier
git checkout -- fichier.cs

# Annuler tous les changements non commités
git reset --hard HEAD
```

---

## 🛡️ Hooks Git automatiques

Les hooks installés effectuent automatiquement :

### Pre-commit (avant chaque commit)
- ✅ Détection de secrets (Gitleaks)
- ✅ Formatage du code (dotnet format)
- ✅ Build de la solution
- ✅ Tests unitaires (optionnel)

### Commit-msg (validation du message)
- ✅ Format Conventional Commits

### Pre-push (avant chaque push)
- ✅ Tous les tests passent
- ⚠️ Avertissement si TODOs présents

### Bypass (en cas d'urgence)

```bash
# Bypasser les hooks (déconseillé !)
git commit --no-verify
git push --no-verify
```

---

## 🔍 Résolution de problèmes

### Conflit de merge

```bash
# 1. Récupérer les changements
git pull origin develop
# Conflit détecté !

# 2. Ouvrir les fichiers en conflit
# Chercher les marqueurs : <<<<<<< HEAD

# 3. Résoudre manuellement

# 4. Marquer comme résolu
git add fichier-resolu.cs

# 5. Finaliser
git commit -m "merge: resolve conflicts with develop"
```

### Branche désynchronisée

```bash
# Votre branche est derrière develop
git checkout feature/ma-feature
git pull origin develop
# OU
git rebase develop
```

### Erreur de push

```bash
# Erreur : "Updates were rejected"
# Raison : votre branche locale est derrière la remote

# Solution 1 : Pull puis push
git pull origin feature/ma-feature
git push origin feature/ma-feature

# Solution 2 : Rebase (plus propre)
git pull --rebase origin feature/ma-feature
git push origin feature/ma-feature
```

---

## 📚 Commandes avancées

### Rebase interactif (nettoyer l'historique)

```bash
# Combiner les 3 derniers commits
git rebase -i HEAD~3

# Dans l'éditeur :
# pick abc123 Premier commit
# squash def456 Deuxième commit  <- Changer pick en squash
# squash ghi789 Troisième commit <- Changer pick en squash
```

### Cherry-pick (appliquer un commit spécifique)

```bash
# Appliquer le commit abc123 sur la branche actuelle
git cherry-pick abc123
```

### Stash (mettre de côté des changements)

```bash
# Sauvegarder les changements non commités
git stash save "work in progress"

# Lister les stashes
git stash list

# Appliquer le dernier stash
git stash pop

# Appliquer un stash spécifique
git stash apply stash@{0}
```

### Recherche dans l'historique

```bash
# Trouver qui a modifié une ligne
git blame fichier.cs

# Chercher un texte dans les commits
git log --all --grep="patient"

# Chercher un texte dans le code
git log -S "searchText"
```

---

## 🎯 Checklist avant chaque commit

- [ ] Code compilé sans erreurs
- [ ] Tests unitaires passent
- [ ] Code formaté (`dotnet format`)
- [ ] Pas de secrets hardcodés
- [ ] Pas de `console.log` oublié
- [ ] Message de commit suit Conventional Commits
- [ ] Changements cohérents (un commit = une chose)

---

## 🎯 Checklist avant chaque push

- [ ] Branche à jour avec develop (`git pull origin develop`)
- [ ] Tous les tests passent
- [ ] Code reviewé par vous-même (auto-review)
- [ ] Documentation mise à jour si nécessaire
- [ ] Pas de TODO/FIXME non résolu dans le code ajouté

---

## 📖 Ressources

### Documentation complète
- [Git Workflow complet](./GIT_WORKFLOW.md)
- [Guide de contribution](../CONTRIBUTING.md)

### Aide
- `git help <command>` - Aide sur une commande
- `git <command> --help` - Aide détaillée

### Liens externes
- [Git Documentation](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

---

## 🆘 Besoin d'aide ?

### En cas de problème Git

1. **Ne paniquez pas !** Git permet presque toujours de récupérer
2. Faites une copie de votre dossier (backup)
3. Consultez `git reflog` pour voir l'historique
4. Demandez de l'aide à l'équipe

### Contacts
- 💬 Channel Slack : #dev-help
- 📧 Email : dev@medsecure.health
- 📖 Wiki : [Git Troubleshooting](https://wiki.medsecure.health/git)

---

**Bon développement ! 🚀**

---

**Dernière mise à jour** : 2026-02-09
**Version** : 1.0.0
