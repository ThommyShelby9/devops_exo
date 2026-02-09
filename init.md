CAS PRATIQUE DEVSECOPS 1
Transformation MedSecure
Industrialisation d'une plateforme HealthTech (.NET + React)
Auteur : Architecture Lead
Secteur : HealthTech / Santé
Niveau : Avancé – Sécurité, Conformité HDS &
Industrialisation
Date : Février 2026
Conformité : HDS • RGPD • ISO 27001
MedSecure – Cas Pratique DevSecOps
Page 2
Informations Générales
Repository Source :
https://github.com/dotnet-architecture/eShopOnWeb
(Microsoft Reference Architecture – Clean Architecture .NET, adapté au contexte
santé)
Repo complémentaire (Frontend React) :
https://github.com/mediwise/mediwise-app OU https://github.com/openemr/openemr
(Applications open-source orientées gestion médicale, utilisées comme
référence fonctionnelle)
Composant Détail
Stack Backend .NET 8 Clean Architecture (DDD), ASP.NET Core Web API, EF
Core 8
Stack Frontend React 18 + TypeScript, Material-UI, Vite
Base de données Azure SQL Database (chiffrement TDE + Always
Encrypted)
Hébergement Azure App Service (HDS certifié) / Azure Kubernetes
Service
Secrets Azure Key Vault (HSM-backed)
IaC Bicep / Terraform
Conformité HDS, RGPD, ISO 27001, ANSSI recommandations
1. Contexte Métier (Storytelling)
L'entreprise : MedSecure
MedSecure est une startup HealthTech française en pleine croissance qui
développe une plateforme de gestion de dossiers patients et de téléconsultation,
utilisée par plus de 500 cabinets médicaux et 3 établissements hospitaliers.
MedSecure – Cas Pratique DevSecOps
Page 3
L'application permet aux professionnels de santé de :
• Gérer les dossiers médicaux électroniques (DME) des patients
• Planifier et réaliser des téléconsultations vidéo sécurisées
• Prescrire des ordonnances numériques signées électroniquement
• Gérer la facturation et le tiers-payant (intégration CPAM)
• Partager des comptes-rendus via le DMP (Dossier Médical Partagé)
Le backend repose sur une Clean Architecture .NET 8 avec séparation stricte
Domain / Application / Infrastructure / API, respectant les principes du DomainDriven Design (DDD). Le frontend est développé en React 18 avec TypeScript et
communique via des APIs REST sécurisées.
Problèmes identifiés
Malgré une architecture logicielle solide, l'industrialisation pose des problèmes
critiques dans un contexte de données de santé :
Problème Impact
Builds manuels Risque d'erreur humaine, délais de livraison de 4h+
Déploiements risqués Downtime lors des mises à jour, 30% d'échec
Secrets en clair dans
appsettings.json
12 secrets hardcodés détectés (clés API, chaînes
SQL)
Migrations DB non automatisées Risque d'incohérence de schéma entre
environnements
Aucun scan de sécurité
automatisé
Non-conformité HDS et RGPD
Pas de traçabilité des accès Audit impossible pour la certification HDS
Enjeux réglementaires spécifiques au secteur santé
Contrairement à un projet e-commerce classique, le secteur de la santé impose
des contraintes réglementaires fortes :
MedSecure – Cas Pratique DevSecOps
Page 4
• HDS (Hébergement de Données de Santé) : Certification obligatoire pour
tout hébergeur de données de santé à caractère personnel. Impose le
chiffrement, la traçabilité et des audits réguliers.
• RGPD (Article 9) : Les données de santé sont des données sensibles
nécessitant des mesures de protection renforcées (consentement explicite,
droit à l'oubli, minimisation).
• ANSSI : Recommandations de sécurité pour les systèmes d'information de
santé (authentification forte, cloisonnement réseau, journalisation).
• PGSSI-S : Politique Générale de Sécurité des Systèmes d'Information de
Santé – cadre de référence national.
Votre mission
Vous êtes recruté(e) comme Lead DevSecOps chez MedSecure. Votre mission
consiste à concevoir et implémenter une chaîne CI/CD DevSecOps robuste
garantissant :
1. Qualité : Zéro régression, couverture de tests > 80%, Quality Gate
SonarCloud
2. Sécurité : 0 secret en clair, scan SAST/DAST/SCA, conformité OWASP Top 10
3. Conformité : Traçabilité complète pour audits HDS, chiffrement bout-enbout
4. Continuité : Déploiement Blue/Green sans interruption, MTTR < 15 minutes
5. Observabilité : Monitoring en temps réel, alertes proactives, SLO 99.95%
MedSecure – Cas Pratique DevSecOps
Page 5
2. Configuration Azure Boards (Agilité Scrum)
Organisation en Scrum avec des sprints de 2 semaines et backlog piloté par la
valeur métier et la conformité réglementaire.
ID User Story Priorité
US-01 Infrastructure as Code : Provisionnement Azure certifié
HDS via Bicep / Terraform
P0
US-02 CI Global : Build et tests automatisés de la solution .NET
8 + React 18
P0
US-03 DevSecOps : Analyse SonarCloud, détection de secrets
(Gitleaks) et scan OWASP
P0
US-04 CD : Déploiement Blue/Green via slots Azure App
Service
P1
US-05 Secrets : Intégration Azure Key Vault avec rotation
automatique (90 jours)
P0
US-06 Conformité : Audit trail et journalisation HDS (Log
Analytics)
P0
US-07 Chiffrement : TDE + Always Encrypted pour les données
patients
P0
US-08 Observabilité : Application Insights + alertes critiques
(SLO 99.95%)
P1
3. Stratégie Azure Repos
Trunk-Based Development modernisé
Dans un contexte de données de santé, la stratégie de branching doit être
rigoureuse avec des contrôles renforcés :
• main : Production (protégée, minimum 2 reviewers dont 1 membre sécurité)
• feature/* : Branches de développement (durée max 2 jours)
• hotfix/* : Corrections urgentes avec processus accéléré
• release/* : Branches de release pour les versions certifiées
MedSecure – Cas Pratique DevSecOps
Page 6
Règles de protection
• Pull Requests obligatoires avec minimum 2 reviewers (dont 1 de l'équipe
sécurité)
• Build de validation CI obligatoire (pipeline doit être vert)
• Lien obligatoire avec les Work Items Azure Boards
• Résolution de tous les commentaires obligatoire
• Scan Gitleaks intégré au pre-commit hook
• CODEOWNERS : équipe sécurité reviewer obligatoire sur appsettings*.json et
Dockerfile
MedSecure – Cas Pratique DevSecOps
Page 7
4. Architecture Azure Pipelines (YAML)
Le pipeline est structuré en stages distincts avec mutualisation via templates
YAML. La spécificité santé se traduit par des étapes de conformité et de
chiffrement supplémentaires.
Stages du pipeline
# Stage Détail
1 Build & Validate dotnet restore / build / test + npm install + npm run
build
2 Security Scanning SonarCloud (SAST), Gitleaks (secrets), Snyk (SCA),
OWASP DC
3 Integration Tests Tests API + E2E Playwright + validation chiffrement
4 Compliance Check Vérification HDS : audit trail, chiffrement TDE, Always
Encrypted
5 Package Build Docker image + scan Trivy + push ACR
6 Deploy Staging Blue/Green + warm-up + health checks + smoke
tests
7 Deploy Production Approbation manuelle + progressive rollout
(10%/50%/100%)
Template Build .NET (dotnet-build.yml)
Le template inclut : restoration NuGet avec cache, build Release, exécution des
tests unitaires avec couverture (seuil 80%), et publication des artefacts.
Template Frontend (react-build.yml)
Le template inclut : installation pnpm, build React optimisé (Vite), et copie du
dossier dist dans les artefacts publiés (wwwroot).
Template Déploiement (deploy-blue-green.yml)
Déploiement ZIP vers le slot staging, warm-up (10 requêtes), health check (30
tentatives / 10s), swap Blue/Green, puis validation post-swap.
MedSecure – Cas Pratique DevSecOps
Page 8
5. Environnements & Sécurité
Environnements Azure DevOps
• DEV : Déploiement automatique, données anonymisées
• STAGING : Déploiement automatique, données de test HDS-conformes
• PRODUCTION : Validation manuelle obligatoire (gate), données réelles
chiffrées
Sécurité spécifique santé
La gestion des secrets et du chiffrement est critique dans le contexte HDS :
• Secrets injectés dynamiquement depuis Azure Key Vault (HSM-backed)
• Substitution JSON automatique dans appsettings.json (aucun secret en
clair)
• Chiffrement TDE activé sur Azure SQL (transparent, au repos)
• Always Encrypted pour les colonnes sensibles (nom patient, numéro sécu,
diagnostics)
• TLS 1.3 obligatoire pour toutes les communications
• Managed Identity pour l'accès App Service → Key Vault (zéro credential)
• Private Endpoints pour Azure SQL et Key Vault (aucun accès public)
Matrice de sécurité multi-couches
Couche Outils Objectif Bloquant
IDE SonarLint, Snyk Détection immédiate Non
Pre-commit Gitleaks, hooks Bloquer secrets Oui
Pull Request SonarCloud, CodeQL Quality Gate Oui (Crit/High)
CI Snyk, OWASP DC,
Trivy
Vulnérabilités Oui (CVSS > 7.0)
Pre-deploy OWASP ZAP (DAST) Scan dynamique Oui (High)
Runtime Azure Defender, WAF Protection temps réel Alerte
Compliance Azure Policy Conformité HDS Oui
MedSecure – Cas Pratique DevSecOps
Page 9
6. Le Défi du Lead DevOps
Scénario 1 : Page blanche après déploiement
Après déploiement, l'application affiche une page blanche ou retourne des
erreurs 404 côté API.
Analyse : Les fichiers statiques React ne sont pas correctement copiés dans
wwwroot.
Solution : Ajuster le pipeline pour inclure le dossier build React (dist/) dans les
artefacts publiés et les copier dans wwwroot avant le déploiement.
Scénario 2 : Fuite de données patients potentielle
Un développeur junior a commité une chaîne de connexion Azure SQL contenant
le mot de passe en clair dans appsettings.Production.json.
Urgence : Révoquer immédiatement le secret dans Azure Key Vault, regénérer le
mot de passe SQL, purger l'historique Git avec git filter-repo, notifier le DPO
(Délégué à la Protection des Données) car les données de santé sont concernées.
Prévention : Activer les pre-commit hooks Gitleaks, rendre le scan de secrets
bloquant dans le pipeline CI, former l'équipe aux bonnes pratiques.
Scénario 3 : Non-conformité HDS détectée lors d'un audit
Un audit HDS révèle que les logs applicatifs contiennent des données patient non
anonymisées (noms, numéros de sécurité sociale).
Analyse : Les logs Serilog ne filtrent pas les PII (Personally Identifiable Information).
Les données sensibles sont enregistrées en clair dans Log Analytics.
Solution : Implémenter un TelemetryProcessor/enricher Serilog qui masque
automatiquement les PII (numéro sécu, noms patients) avant envoi vers
Application Insights. Ajouter un test automatisé dans le pipeline CI vérifiant
l'absence de PII dans les logs.
MedSecure – Cas Pratique DevSecOps
Page 10
7. Critères de Succès – KPI
Catégorie Indicateur (KPI) Objectif Seuil
acceptable
Build Pipeline CI vert 100% > 95%
Tests Taux de réussite des tests > 98% > 95%
Tests Code coverage > 80% > 70%
Sécurité Secrets détectés 0 0 (bloquant)
Sécurité Vulnérabilités Critical/High 0 0 (bloquant)
Qualité SonarCloud Quality Gate Pass Pass
CD Disponibilité applicative (SLO) > 99.95% > 99.9%
CD Temps de rollback (MTTR) < 5 min < 15 min
Conformité Audit HDS : traçabilité 100% 100% 100%
(obligatoire)
Conformité PII dans les logs 0 0 (obligatoire)
Performance API Latency p95 < 500ms < 1000ms
8. Justification du Repository Source
Pourquoi eShopOnWeb de Microsoft ?
Le repository eShopOnWeb (https://github.com/dotnetarchitecture/eShopOnWeb) est la référence officielle Microsoft pour la Clean
Architecture .NET. Il constitue une base technique idéale pour ce cas pratique car :
• Clean Architecture stricte avec séparation Domain / Application /
Infrastructure / Web
• Stack .NET 8 + EF Core avec patterns DDD (Repository, Specification)
• Projet activement maintenu par Microsoft (dernière mise à jour récente)
• Inclut déjà des tests unitaires et d'intégration
• Structure monorepo adaptée à l'industrialisation CI/CD
Adaptation au contexte santé
MedSecure – Cas Pratique DevSecOps
Page 11
Bien que le repo original soit orienté e-commerce, le storytelling MedSecure
transpose les concepts métier :
Concept eShopOnWeb Transposition MedSecure Enjeu DevSecOps
Catalogue produits Dossiers médicaux (DME) Chiffrement Always
Encrypted
Panier / Commandes Rendez-vous /
Consultations
Traçabilité HDS
Paiement Facturation / Tiers-payant Conformité RGPD
Utilisateurs Patients / Médecins Authentification forte (MFA)
Notifications email Alertes médicales PII masquées dans les logs
Cette transposition permet aux apprenants de travailler sur un repo réel et bien
structuré, tout en intégrant les contraintes spécifiques du secteur santé qui font
toute la différence en matière de DevSecOps.
9. Repos Alternatifs (Optionnel)
Pour aller plus loin ou pour un exercice plus immersif, les apprenants peuvent
également explorer :
Repository Description Intérêt
open-emr/openemr Système EMR opensource (PHP)
Référence fonctionnelle
santé
bahmni/bahmni-core Plateforme hospitalière
open-source (Java)
Architecture
microservices santé
jasmine-health/jasmine App santé React +
Node.js
Frontend santé
moderne
dotnetarchitecture/eShopOnContainers
Microservices .NET +
Docker + K8s
Défi avancé :
conteneurisation
Le choix du repo eShopOnWeb comme référence principale reste recommandé
car il offre la meilleure base Clean Architecture .NET, directement alignable avec
MedSecure – Cas Pratique DevSecOps
Page 12
les pipelines Azure DevOps et les outils DevSecOps couverts dans ce cas
pratique.