# 🚀 Démarrage de MedSecure en Local

Guide complet pour exécuter la plateforme MedSecure sur votre machine de développement.

---

## 📋 Prérequis

### Obligatoires

- ✅ **Docker Desktop** (pour SQL Server, Redis, etc.)
  - Windows : [Télécharger Docker Desktop](https://www.docker.com/products/docker-desktop)
  - Version minimale : 20.10+

- ✅ **.NET 8 SDK**
  - [Télécharger .NET 8](https://dotnet.microsoft.com/download/dotnet/8.0)
  - Vérifier : `dotnet --version`

- ✅ **PowerShell 7+** (pour les scripts)
  - Windows : Déjà installé
  - Vérifier : `pwsh --version`

### Optionnels (recommandés)

- 🔧 **Visual Studio 2022** ou **VS Code**
- 🔧 **SQL Server Management Studio (SSMS)** - Pour gérer la base de données
- 🔧 **Git** - Pour cloner le repository

---

## 🏃 Démarrage rapide (Quick Start)

### Méthode 1 : Script automatique (RECOMMANDÉ)

```powershell
# 1. Ouvrir PowerShell dans le dossier du projet
cd O:\Projets\Formation\cas2

# 2. Exécuter le script de démarrage
.\Start-MedSecureLocal.ps1 -BuildFirst
```

**C'est tout !** Le script va automatiquement :
- ✅ Vérifier les prérequis
- ✅ Démarrer Docker (SQL Server, Redis, MailHog, Azurite)
- ✅ Compiler l'application
- ✅ Créer et initialiser les bases de données
- ✅ Démarrer l'application Web

### Méthode 2 : Étape par étape (manuel)

Si vous préférez contrôler chaque étape :

```powershell
# 1. Démarrer les services Docker
docker-compose -f docker-compose.local.yml up -d

# 2. Attendre que SQL Server soit prêt (30-60 secondes)
docker logs medsecure-sql --follow
# Appuyer sur Ctrl+C quand vous voyez "SQL Server is now ready"

# 3. Compiler l'application
dotnet restore
dotnet build

# 4. Appliquer les migrations de base de données
cd src\Web
dotnet ef database update --context CatalogContext
dotnet ef database update --context AppIdentityDbContext
cd ..\..

# 5. Démarrer l'application Web
cd src\Web
dotnet run
```

---

## 🌐 URLs de l'application

Une fois démarré, accédez à :

| Service | URL | Description |
|---------|-----|-------------|
| **Application Web** | https://localhost:44315 | Interface principale MedSecure |
| **API REST** | https://localhost:5099 | API publique (Swagger : /swagger) |
| **Admin Blazor** | https://localhost:5099 | Interface d'administration |
| **MailHog** | http://localhost:8025 | Visualiser les emails (SMTP local) |

### URLs des services backend

| Service | Port | Connexion |
|---------|------|-----------|
| SQL Server | 1433 | `Server=localhost,1433;User=sa;Password=MedSecure2024!` |
| Redis | 6379 | `localhost:6379` |
| Azurite (Blob) | 10000 | Émulateur Azure Storage |
| Azurite (Queue) | 10001 | Émulateur Azure Storage |

---

## 🔐 Comptes de test

### Compte administrateur

- **Email** : `admin@medsecure.local`
- **Mot de passe** : `Pass@word1`

### Compte utilisateur

- **Email** : `demouser@medsecure.local`
- **Mot de passe** : `Pass@word1`

> **Note** : Ces comptes sont créés automatiquement lors de la première initialisation de la base de données.

---

## 🛠️ Options du script de démarrage

### Commandes disponibles

```powershell
# Démarrage complet avec recompilation
.\Start-MedSecureLocal.ps1 -BuildFirst

# Démarrage sans Docker (si déjà lancé)
.\Start-MedSecureLocal.ps1 -SkipDocker

# Démarrage uniquement de l'application Web (sans API)
.\Start-MedSecureLocal.ps1 -WebOnly

# Combinaison
.\Start-MedSecureLocal.ps1 -SkipDocker -WebOnly
```

### Paramètres

| Paramètre | Description |
|-----------|-------------|
| `-BuildFirst` | Recompile l'application avant de démarrer |
| `-SkipDocker` | Ne démarre pas les containers Docker (doit être déjà lancé) |
| `-WebOnly` | Démarre uniquement l'application Web (pas l'API) |

---

## 🗄️ Gestion de la base de données

### Connexion à SQL Server

```bash
# Via Docker
docker exec -it medsecure-sql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "MedSecure2024!"

# Via SSMS
Server: localhost,1433
Login: sa
Password: MedSecure2024!
```

### Bases de données créées

- **MedSecureDB** - Catalogue de produits/services
- **MedSecureIdentity** - Gestion des utilisateurs et authentification

### Réinitialiser la base de données

```powershell
cd src\Web

# Supprimer et recréer
dotnet ef database drop --force --context CatalogContext
dotnet ef database drop --force --context AppIdentityDbContext

# Appliquer les migrations
dotnet ef database update --context CatalogContext
dotnet ef database update --context AppIdentityDbContext
```

### Créer une nouvelle migration

```powershell
cd src\Web

# Migration pour le catalogue
dotnet ef migrations add MaMigration --context CatalogContext

# Migration pour l'identité
dotnet ef migrations add MaMigration --context AppIdentityDbContext
```

---

## 🐋 Gestion de Docker

### Commandes utiles

```bash
# Démarrer les services
docker-compose -f docker-compose.local.yml up -d

# Arrêter les services
docker-compose -f docker-compose.local.yml down

# Arrêter et supprimer les volumes (ATTENTION: perte de données)
docker-compose -f docker-compose.local.yml down -v

# Voir les logs
docker-compose -f docker-compose.local.yml logs -f

# Voir les logs d'un service spécifique
docker logs medsecure-sql -f
docker logs medsecure-redis -f

# Redémarrer un service
docker restart medsecure-sql

# Vérifier l'état des services
docker-compose -f docker-compose.local.yml ps
```

### Volumes Docker

Les données sont stockées dans des volumes Docker :
- `medsecure_sqlserver-data` - Base de données SQL Server
- `medsecure_redis-data` - Cache Redis
- `medsecure_azurite-data` - Émulateur Azure Storage

---

## 📧 MailHog - Email local

MailHog capture tous les emails envoyés par l'application.

### Accès

- **Interface Web** : http://localhost:8025
- **SMTP** : localhost:1025

### Utilisation

Tous les emails envoyés par l'application (réinitialisation de mot de passe, notifications, etc.) sont capturés par MailHog et visibles dans l'interface web.

---

## 🔍 Debugging

### Visual Studio 2022

1. Ouvrir `eShopOnWeb.sln`
2. Définir `Web` comme projet de démarrage
3. Appuyer sur F5

### VS Code

1. Ouvrir le dossier du projet
2. Installer l'extension C# Dev Kit
3. Ouvrir `src/Web/Program.cs`
4. Appuyer sur F5

### Logs de l'application

```powershell
# Niveau de log détaillé
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run --project src\Web\Web.csproj
```

Les logs sont affichés dans la console et dans :
- Console (stdout)
- `src/Web/Logs/` (si configuré)

---

## 🧹 Nettoyage et redémarrage

### Problème : L'application ne démarre pas

```powershell
# 1. Arrêter tout
docker-compose -f docker-compose.local.yml down -v

# 2. Nettoyer les builds
dotnet clean
Remove-Item -Recurse -Force src\Web\bin, src\Web\obj

# 3. Redémarrer proprement
.\Start-MedSecureLocal.ps1 -BuildFirst
```

### Problème : SQL Server ne démarre pas

```bash
# Vérifier les logs
docker logs medsecure-sql

# Redémarrer le container
docker restart medsecure-sql

# Si ça ne fonctionne pas, recréer
docker-compose -f docker-compose.local.yml down
docker-compose -f docker-compose.local.yml up -d sqlserver
```

### Problème : Port déjà utilisé

```powershell
# Trouver le processus qui utilise le port 44315
netstat -ano | findstr :44315

# Tuer le processus (remplacer PID par le numéro trouvé)
taskkill /PID <PID> /F
```

---

## 🧪 Tests

### Tests unitaires

```powershell
dotnet test tests/UnitTests/UnitTests.csproj
```

### Tests d'intégration

```powershell
# Démarrer d'abord Docker
docker-compose -f docker-compose.local.yml up -d

# Exécuter les tests
dotnet test tests/IntegrationTests/IntegrationTests.csproj
```

### Tests fonctionnels

```powershell
dotnet test tests/FunctionalTests/FunctionalTests.csproj
```

---

## 📚 Ressources additionnelles

### Documentation

- [Guide complet](./docs/README.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Configuration Application Insights](./docs/APPLICATION_INSIGHTS_GUIDE.md)
- [Chiffrement TDE et Always Encrypted](./docs/ENCRYPTION_TDE_ALWAYS_ENCRYPTED_GUIDE.md)

### Raccourcis utiles

```powershell
# Ouvrir SSMS
ssms

# Ouvrir le projet dans Visual Studio
start eShopOnWeb.sln

# Ouvrir le projet dans VS Code
code .
```

---

## ❓ FAQ

### Q: Dois-je installer SQL Server localement ?

**R:** Non ! SQL Server tourne dans Docker. Pas besoin d'installation locale.

### Q: Puis-je utiliser ma propre base de données SQL Server ?

**R:** Oui, modifiez les connection strings dans `src/Web/appsettings.Development.json`

### Q: Comment changer le port de l'application ?

**R:** Modifiez `src/Web/Properties/launchSettings.json`

### Q: L'application est lente au premier démarrage

**R:** C'est normal, .NET compile à la première requête. Les démarrages suivants sont plus rapides.

### Q: Puis-je désactiver HTTPS en développement ?

**R:** Oui, mais non recommandé. Si nécessaire, modifiez `launchSettings.json`

---

## 🆘 Support

En cas de problème :

1. Vérifier les logs Docker : `docker-compose logs -f`
2. Vérifier les logs de l'application (console)
3. Consulter la section Dépannage ci-dessus
4. Ouvrir une issue sur GitHub

---

## 🎉 Prêt à coder !

Votre environnement de développement local MedSecure est maintenant configuré !

**Commandes rapides** :
```powershell
# Démarrer
.\Start-MedSecureLocal.ps1 -BuildFirst

# Accéder à l'application
start https://localhost:44315

# Voir les emails
start http://localhost:8025
```

**Bon développement ! 🚀**

---

**Dernière mise à jour** : 2026-02-09
**Version** : 1.0.0
