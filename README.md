# MedSecure - Plateforme HealthTech Sécurisée

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-8.0-purple.svg)](https://dotnet.microsoft.com/)
[![React](https://img.shields.io/badge/React-18-blue.svg)](https://reactjs.org/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4.svg)](https://azure.microsoft.com/)
[![HDS](https://img.shields.io/badge/Conformit%C3%A9-HDS-green.svg)](https://esante.gouv.fr/labels-certifications/hds)
[![RGPD](https://img.shields.io/badge/Conformit%C3%A9-RGPD-green.svg)](https://www.cnil.fr/fr/reglement-europeen-protection-donnees)
[![ISO 27001](https://img.shields.io/badge/ISO-27001-green.svg)](https://www.iso.org/isoiec-27001-information-security.html)

> Plateforme de gestion de dossiers patients et téléconsultation sécurisée, conforme aux exigences HDS, RGPD et ISO 27001.

---

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Architecture](#-architecture)
- [Fonctionnalités](#-fonctionnalités)
- [Technologies](#-technologies)
- [Conformité & Sécurité](#-conformité--sécurité)
- [Démarrage rapide](#-démarrage-rapide)
- [Structure du projet](#-structure-du-projet)
- [Documentation](#-documentation)
- [DevSecOps](#-devsecops)
- [Contribution](#-contribution)
- [License](#-license)

---

## 🏥 Vue d'ensemble

**MedSecure** est une plateforme HealthTech française développée pour faciliter la gestion des dossiers médicaux électroniques (DME) et les téléconsultations sécurisées. Utilisée par plus de 500 cabinets médicaux et 3 établissements hospitaliers.

### Cas d'usage

- ✅ **Gestion DME** : Dossiers médicaux électroniques sécurisés
- ✅ **Téléconsultations** : Vidéo sécurisée avec chiffrement bout-en-bout
- ✅ **e-Prescriptions** : Ordonnances numériques signées électroniquement
- ✅ **Facturation** : Intégration CPAM et tiers-payant
- ✅ **DMP** : Partage de comptes-rendus via Dossier Médical Partagé

### Contexte réglementaire

MedSecure gère des **données de santé à caractère personnel** (RGPD Article 9), nécessitant :

- 🔐 **HDS** : Hébergement de Données de Santé certifié
- 🔐 **RGPD** : Protection des données renforcée
- 🔐 **ISO 27001** : Management de la sécurité de l'information
- 🔐 **ANSSI** : Recommandations de sécurité pour systèmes de santé
- 🔐 **PGSSI-S** : Politique Générale de Sécurité des SI de Santé

---

## 🏗️ Architecture

### Architecture globale

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Cloud (HDS)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │   Frontend   │      │   Backend    │      │   Database   │ │
│  │  React 18 +  │─────▶│  .NET 8 API  │─────▶│  Azure SQL   │ │
│  │  TypeScript  │      │ Clean Arch.  │      │  TDE + AE    │ │
│  └──────────────┘      └──────────────┘      └──────────────┘ │
│         │                      │                      │         │
│         │                      │                      │         │
│         ▼                      ▼                      ▼         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Application Insights + Monitoring            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │  Key Vault   │      │     ACR      │      │ Log Analytics│ │
│  │  (Premium)   │      │  (Premium)   │      │  Workspace   │ │
│  │  HSM-backed  │      │   Docker     │      │  90d retain  │ │
│  └──────────────┘      └──────────────┘      └──────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Clean Architecture (.NET 8)

```
src/
├── ApplicationCore/      # Domain Layer (Entities, Interfaces, Services)
├── Infrastructure/       # Persistence, External Services
├── Web/                  # Presentation (MVC, Pages)
└── PublicApi/            # REST API
```

**Principes DDD** :
- ✅ Separation of Concerns
- ✅ Dependency Inversion
- ✅ Repository Pattern
- ✅ Specification Pattern

---

## ✨ Fonctionnalités

### Fonctionnalités métier

| Fonctionnalité | Description | Statut |
|----------------|-------------|--------|
| **Gestion patients** | CRUD dossiers patients avec chiffrement | ✅ |
| **Consultations** | Planification et historique | ✅ |
| **Téléconsultation** | Vidéo sécurisée (WebRTC) | 🚧 |
| **e-Prescriptions** | Ordonnances numériques signées | 🚧 |
| **Facturation** | Intégration CPAM | 🚧 |
| **DMP** | Export vers Dossier Médical Partagé | 📋 |

### Fonctionnalités techniques

- ✅ **Authentification** : ASP.NET Identity + MFA
- ✅ **Autorisation** : RBAC (Role-Based Access Control)
- ✅ **Audit trail** : Logs complets (90 jours minimum)
- ✅ **Chiffrement** : TDE + Always Encrypted + TLS 1.3
- ✅ **Monitoring** : Application Insights + Log Analytics
- ✅ **Health checks** : Validation avant déploiement
- ✅ **Blue/Green** : Déploiement sans interruption

---

## 🛠️ Technologies

### Backend

- **Runtime** : .NET 8 (LTS)
- **Framework** : ASP.NET Core Web API
- **ORM** : Entity Framework Core 8
- **Base de données** : Azure SQL Database
- **Authentification** : ASP.NET Core Identity
- **Logging** : Serilog + Application Insights

### Frontend

- **Framework** : React 18
- **Language** : TypeScript 5
- **UI** : Material-UI (MUI)
- **Build** : Vite
- **State** : Redux Toolkit (ou Context API)

### Infrastructure (Azure)

| Service | SKU | Usage |
|---------|-----|-------|
| **App Service** | S1 Standard | Hébergement application |
| **App Service Plan** | S1 | Support Blue/Green (5 slots) |
| **SQL Database** | Basic | Bases de données (Catalog + Identity) |
| **Key Vault** | Premium | Secrets HSM-backed |
| **Container Registry** | Premium | Images Docker |
| **Log Analytics** | PerGB2018 | Centralisation logs (90 jours) |
| **Application Insights** | - | APM et monitoring |

### DevSecOps

- **CI/CD** : Azure Pipelines (YAML)
- **IaC** : Bicep (ARM templates)
- **SAST** : SonarCloud
- **SCA** : Snyk + OWASP Dependency Check
- **Secrets** : Gitleaks
- **Container Scan** : Trivy
- **DAST** : OWASP ZAP

---

## 🔐 Conformité & Sécurité

### Matrice de conformité

| Exigence | Implémentation | Statut |
|----------|----------------|--------|
| **HDS - Chiffrement au repos** | TDE + Always Encrypted | ✅ |
| **HDS - Chiffrement en transit** | TLS 1.3 | ✅ |
| **HDS - Audit trail** | Log Analytics (90 jours) | ✅ |
| **HDS - Traçabilité accès** | Diagnostics complets | ✅ |
| **HDS - Sauvegarde** | Azure SQL Backups | ✅ |
| **RGPD - Minimisation** | Always Encrypted colonnes sensibles | ✅ |
| **RGPD - Droit à l'oubli** | Soft delete + Purge | ✅ |
| **RGPD - Portabilité** | Export JSON/XML | 🚧 |
| **ISO 27001 - Gestion accès** | RBAC + MFA | ✅ |
| **ISO 27001 - Gestion incidents** | Alertes + Playbooks | 🚧 |
| **ANSSI - Auth forte** | MFA obligatoire | 🚧 |
| **ANSSI - Cloisonnement** | Private Endpoints | 📋 |

### Chiffrement multi-couches

```
┌─────────────────────────────────────────────────────────┐
│ 1. TLS 1.3           │ En transit (Client ↔ Server)    │
├─────────────────────────────────────────────────────────┤
│ 2. TDE               │ Au repos (Database complète)    │
├─────────────────────────────────────────────────────────┤
│ 3. Always Encrypted  │ Colonnes sensibles (Patients)   │
├─────────────────────────────────────────────────────────┤
│ 4. Key Vault Premium │ Clés protégées par HSM          │
└─────────────────────────────────────────────────────────┘
```

### Audit trail complet

Tous les accès sont loggés dans Log Analytics avec rétention 90 jours :

- ✅ **HTTP Requests** : IP, URL, User, Timestamp, Status
- ✅ **Database Access** : Query, User, Table, Timestamp
- ✅ **Key Vault Access** : Secret, User, IP, Timestamp
- ✅ **Configuration Changes** : Before/After, User, Timestamp

---

## 🚀 Démarrage rapide

### Prérequis

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Node.js 18+](https://nodejs.org/) (pour le frontend React)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (optionnel)

### Installation locale (Dev)

```bash
# 1. Cloner le repository
git clone https://github.com/your-org/medsecure.git
cd medsecure

# 2. Restaurer les dépendances .NET
dotnet restore

# 3. Configurer les secrets (local)
dotnet user-secrets set "ConnectionStrings:CatalogConnection" "Server=localhost;Database=Catalog;..."
dotnet user-secrets set "ConnectionStrings:IdentityConnection" "Server=localhost;Database=Identity;..."

# 4. Appliquer les migrations
dotnet ef database update --project src/Infrastructure --startup-project src/Web

# 5. Lancer l'application
dotnet run --project src/Web

# L'application est disponible sur https://localhost:5001
```

### Déploiement Azure (avec azd)

```bash
# 1. Login Azure
azd auth login

# 2. Initialiser l'environnement
azd env new medsecure-dev

# 3. Déployer infrastructure + application
azd up

# 4. Accéder à l'application
azd show
```

### Déploiement Azure (avec script PowerShell)

```powershell
# Déployer en DEV
.\scripts\deploy.ps1 -Environment dev

# Déployer en STAGING (What-If preview)
.\scripts\deploy.ps1 -Environment staging -WhatIf

# Déployer en PROD (Infrastructure uniquement)
.\scripts\deploy.ps1 -Environment prod -SkipApplication
```

---

## 📁 Structure du projet

```
medsecure/
├── src/
│   ├── ApplicationCore/          # Domain Layer
│   │   ├── Entities/             # Domain entities (Patient, Consultation, etc.)
│   │   ├── Interfaces/           # Repository & Service interfaces
│   │   ├── Services/             # Domain services
│   │   └── Specifications/       # Query specifications
│   │
│   ├── Infrastructure/           # Infrastructure Layer
│   │   ├── Data/                 # EF Core DbContext & Configurations
│   │   ├── Identity/             # ASP.NET Identity
│   │   ├── Logging/              # Serilog configuration
│   │   └── Services/             # External services (Email, SMS, etc.)
│   │
│   ├── Web/                      # Presentation Layer (MVC)
│   │   ├── Controllers/
│   │   ├── ViewModels/
│   │   ├── Pages/                # Razor Pages
│   │   └── wwwroot/              # Static files (CSS, JS)
│   │
│   └── PublicApi/                # REST API Layer
│       ├── Controllers/
│       ├── DTOs/
│       └── Endpoints/            # Minimal APIs (optionnel)
│
├── tests/
│   ├── UnitTests/                # Tests unitaires
│   ├── IntegrationTests/         # Tests d'intégration
│   └── FunctionalTests/          # Tests end-to-end
│
├── infra/                        # Infrastructure as Code (Bicep)
│   ├── main.bicep                # Template principal
│   ├── main.parameters.*.json    # Paramètres par environnement
│   └── core/                     # Modules réutilisables
│       ├── host/                 # App Service, App Service Plan
│       ├── database/             # SQL Server
│       ├── security/             # Key Vault, Role Assignments
│       ├── monitor/              # Log Analytics, App Insights
│       └── container/            # Container Registry
│
├── docs/                         # Documentation
│   ├── DEPLOYMENT_GUIDE.md       # Guide de déploiement
│   ├── ALWAYS_ENCRYPTED_GUIDE.md # Configuration Always Encrypted
│   ├── KEY_VAULT_AUDIT_GUIDE.md  # Audit Key Vault
│   ├── HEALTH_CHECK_DIAGNOSTICS_GUIDE.md
│   ├── AZURE_CONTAINER_REGISTRY_GUIDE.md
│   └── APP_SERVICE_SKU_COMPARISON.md
│
├── scripts/                      # Scripts d'automatisation
│   └── deploy.ps1                # Script de déploiement
│
├── .github/workflows/            # GitHub Actions (optionnel)
├── azure-pipelines.yml           # Azure Pipelines CI/CD
├── .env.example                  # Template variables d'environnement
├── docker-compose.yml            # Composition Docker (dev local)
├── Dockerfile                    # Image Docker production
└── README.md                     # Ce fichier
```

---

## 📚 Documentation

### Guides techniques

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) | Guide complet de déploiement (azd, Azure CLI, scripts) |
| [ALWAYS_ENCRYPTED_GUIDE.md](docs/ALWAYS_ENCRYPTED_GUIDE.md) | Configuration chiffrement colonnes (EF Core) |
| [KEY_VAULT_AUDIT_GUIDE.md](docs/KEY_VAULT_AUDIT_GUIDE.md) | Audit trail Key Vault, requêtes KQL, alertes |
| [HEALTH_CHECK_DIAGNOSTICS_GUIDE.md](docs/HEALTH_CHECK_DIAGNOSTICS_GUIDE.md) | Health checks .NET 8, diagnostics, monitoring |
| [AZURE_CONTAINER_REGISTRY_GUIDE.md](docs/AZURE_CONTAINER_REGISTRY_GUIDE.md) | Docker, ACR, pipelines CI/CD, scan Trivy |
| [APP_SERVICE_SKU_COMPARISON.md](docs/APP_SERVICE_SKU_COMPARISON.md) | Comparaison B1 vs S1 vs P1V2, auto-scaling |

### Architecture Decision Records (ADR)

📋 À créer : `docs/adr/`
- ADR-001 : Choix de Clean Architecture
- ADR-002 : TLS 1.3 au lieu de TLS 1.2
- ADR-003 : Key Vault Premium (HSM) pour HDS
- ADR-004 : App Service Plan S1 vs B1

---

## 🔄 DevSecOps

### Pipeline CI/CD

```yaml
# azure-pipelines.yml
stages:
  1. Build & Test        # dotnet build + test + coverage
  2. Security Scan       # SonarCloud, Gitleaks, Snyk, OWASP
  3. Docker Build        # Build + scan Trivy
  4. Deploy Staging      # Blue/Green deployment
  5. Smoke Tests         # Health check + API tests
  6. Deploy Production   # Manual approval required
```

### Matrice de sécurité

| Couche | Outil | Objectif | Bloquant |
|--------|-------|----------|----------|
| **IDE** | SonarLint, Snyk | Détection immédiate | Non |
| **Pre-commit** | Gitleaks | Bloquer secrets | Oui |
| **Pull Request** | SonarCloud, CodeQL | Quality Gate | Oui (Crit/High) |
| **CI** | Snyk, OWASP DC, Trivy | Vulnérabilités | Oui (CVSS > 7.0) |
| **Pre-deploy** | OWASP ZAP (DAST) | Scan dynamique | Oui (High) |
| **Runtime** | Azure Defender, WAF | Protection temps réel | Alerte |
| **Compliance** | Azure Policy | Conformité HDS | Oui |

### KPI DevSecOps

| Métrique | Objectif | Seuil acceptable |
|----------|----------|------------------|
| **Build success rate** | 100% | > 95% |
| **Test success rate** | > 98% | > 95% |
| **Code coverage** | > 80% | > 70% |
| **Secrets détectés** | 0 | 0 (bloquant) |
| **Vulnérabilités Critical/High** | 0 | 0 (bloquant) |
| **SonarCloud Quality Gate** | Pass | Pass |
| **Deployment frequency** | Daily | Weekly |
| **MTTR (rollback)** | < 5 min | < 15 min |

---

## 🤝 Contribution

### Workflow Git (Trunk-Based Development)

```bash
# 1. Créer une branche feature
git checkout -b feature/add-patient-export

# 2. Développer + commits atomiques
git add .
git commit -m "feat: add patient data export to JSON"

# 3. Push et créer une Pull Request
git push origin feature/add-patient-export

# 4. Code Review (2 reviewers minimum, dont 1 sécurité)

# 5. Merge vers main après validation CI + reviewers
```

### Règles de protection (main)

- ✅ Pull Request obligatoire
- ✅ Minimum 2 reviewers (dont 1 équipe sécurité)
- ✅ CI doit être vert (tests + security)
- ✅ Tous les commentaires résolus
- ✅ Lien avec Work Item Azure Boards

### Conventions de commit

Suivre [Conventional Commits](https://www.conventionalcommits.org/) :

```
feat: add patient export feature
fix: correct TDE encryption configuration
docs: update deployment guide
chore: upgrade dependencies
test: add integration tests for consultations
security: patch SQL injection vulnerability
```

---

## 📊 Statut du projet

### Roadmap

#### ✅ Phase 1 : MVP (Q1 2026)
- [x] Architecture Clean Architecture .NET 8
- [x] Infrastructure Azure (Bicep IaC)
- [x] Chiffrement TDE + Always Encrypted
- [x] CI/CD DevSecOps
- [x] Gestion patients (CRUD)
- [x] Health checks + Monitoring

#### 🚧 Phase 2 : Certification HDS (Q2 2026)
- [ ] Private Endpoints (SQL + Key Vault)
- [ ] Téléconsultation (WebRTC)
- [ ] e-Prescriptions signées
- [ ] Audit complet HDS
- [ ] Tests de pénétration

#### 📋 Phase 3 : Scale national (Q3-Q4 2026)
- [ ] Multi-tenancy
- [ ] Geo-replication
- [ ] CDN pour assets statiques
- [ ] Support 10 000+ utilisateurs
- [ ] Intégration DMP national

---

## 📄 License

Ce projet est sous licence [MIT](LICENSE).

**Note** : Ce projet est un cas pratique pédagogique basé sur [eShopOnWeb](https://github.com/dotnet-architecture/eShopOnWeb) de Microsoft.

---

## 🆘 Support

### Problèmes techniques

- 📧 Email : support@medsecure.fr
- 🐛 Issues : [GitHub Issues](https://github.com/your-org/medsecure/issues)
- 💬 Discord : [MedSecure Community](https://discord.gg/medsecure)

### Documentation complémentaire

- [Microsoft Clean Architecture eBook](https://aka.ms/webappebook)
- [HDS - e-Santé](https://esante.gouv.fr/labels-certifications/hds)
- [RGPD - CNIL](https://www.cnil.fr/fr/rgpd-de-quoi-parle-t-on)
- [ANSSI Recommandations](https://www.ssi.gouv.fr/)

---

<div align="center">

**MedSecure** - Sécurité et santé au cœur de l'innovation

Made with ❤️ by the MedSecure Team

[![HDS Certified](https://img.shields.io/badge/HDS-Certified-green.svg)](https://esante.gouv.fr/)
[![RGPD Compliant](https://img.shields.io/badge/RGPD-Compliant-green.svg)](https://www.cnil.fr/)
[![ISO 27001](https://img.shields.io/badge/ISO%2027001-Certified-green.svg)](https://www.iso.org/)

</div>
