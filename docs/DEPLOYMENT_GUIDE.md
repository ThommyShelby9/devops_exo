# Guide de Déploiement MedSecure

## 📋 Prérequis

### Outils requis
- ✅ [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) >= 2.50.0
- ✅ [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) >= 1.5.0
- ✅ [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) >= 7.0 (ou Bash)
- ✅ [.NET SDK](https://dotnet.microsoft.com/download) 8.0
- ✅ [Docker Desktop](https://www.docker.com/products/docker-desktop) (pour containers)

### Permissions Azure requises
- ✅ **Contributor** sur la souscription Azure
- ✅ **User Access Administrator** (pour role assignments)
- ✅ Accès pour créer des Service Principals

### Vérification des outils

```bash
# Azure CLI
az --version

# Azure Developer CLI
azd version

# .NET SDK
dotnet --version

# Docker
docker --version
```

## 🚀 Déploiement rapide (Azure Developer CLI)

### Méthode 1 : Avec azd (Recommandé)

```bash
# 1. Login Azure
azd auth login

# 2. Initialiser l'environnement
azd env new medsecure-dev

# 3. Déployer l'infrastructure + application
azd up

# 4. Accéder à l'application
azd show
```

### Méthode 2 : Avec Azure CLI (Manuel)

#### Étape 1 : Configuration initiale

```bash
# Login Azure
az login

# Sélectionner la souscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Créer un Service Principal pour le déploiement
az ad sp create-for-rbac \
  --name "sp-medsecure-deployer" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth

# Sauvegarder les credentials retournés (clientId, clientSecret, tenantId)
```

#### Étape 2 : Créer les secrets initiaux

**⚠️ IMPORTANT : Les mots de passe doivent être créés AVANT le déploiement**

```powershell
# PowerShell - Générer des mots de passe sécurisés
$sqlAdminPassword = -join ((33..126) | Get-Random -Count 24 | ForEach-Object {[char]$_})
$appUserPassword = -join ((33..126) | Get-Random -Count 24 | ForEach-Object {[char]$_})

Write-Host "SQL Admin Password: $sqlAdminPassword"
Write-Host "App User Password: $appUserPassword"

# SAUVEGARDER CES MOTS DE PASSE de manière sécurisée (Password manager)
```

```bash
# Bash - Générer des mots de passe sécurisés
SQL_ADMIN_PASSWORD=$(openssl rand -base64 24)
APP_USER_PASSWORD=$(openssl rand -base64 24)

echo "SQL Admin Password: $SQL_ADMIN_PASSWORD"
echo "App User Password: $APP_USER_PASSWORD"

# SAUVEGARDER CES MOTS DE PASSE de manière sécurisée
```

#### Étape 3 : Déployer l'infrastructure

```bash
# Variables
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
LOCATION="francecentral"
ENV_NAME="medsecure-dev"
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

# Déployer au niveau subscription
az deployment sub create \
  --location $LOCATION \
  --template-file infra/main.bicep \
  --parameters environmentName=$ENV_NAME \
               location=$LOCATION \
               principalId=$PRINCIPAL_ID \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD"

# Récupérer les outputs
az deployment sub show \
  --name main \
  --query properties.outputs
```

#### Étape 4 : Utiliser les fichiers de paramètres

**Pour DEV :**
```bash
# Modifier infra/main.parameters.dev.json
# Remplacer {subscription-id} par votre subscription ID

az deployment sub create \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD" \
               principalId=$PRINCIPAL_ID
```

**Pour STAGING :**
```bash
az deployment sub create \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.staging.json \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD" \
               principalId=$PRINCIPAL_ID
```

**Pour PRODUCTION :**
```bash
az deployment sub create \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.prod.json \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD" \
               principalId=$PRINCIPAL_ID
```

## 🔐 Gestion des secrets

### Option 1 : Secrets dans Key Vault (Recommandé pour PROD)

```bash
# 1. Créer un Key Vault temporaire pour les secrets de déploiement
az keyvault create \
  --name kv-medsecure-deploy \
  --resource-group rg-medsecure-common \
  --location francecentral \
  --enabled-for-template-deployment true

# 2. Stocker les secrets
az keyvault secret set \
  --vault-name kv-medsecure-deploy \
  --name sqlAdminPassword \
  --value "$SQL_ADMIN_PASSWORD"

az keyvault secret set \
  --vault-name kv-medsecure-deploy \
  --name appUserPassword \
  --value "$APP_USER_PASSWORD"

# 3. Déployer en référençant le Key Vault
# Les fichiers main.parameters.{env}.json utilisent déjà cette syntaxe
```

### Option 2 : Variables d'environnement (DEV uniquement)

```bash
# .env file (NEVER commit to git)
export SQL_ADMIN_PASSWORD="your-password"
export APP_USER_PASSWORD="your-password"

# Déploiement
az deployment sub create \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD"
```

## 📦 Déploiement de l'application

### Build et Push de l'image Docker

```bash
# 1. Login ACR
ACR_NAME=$(az deployment sub show --name main --query properties.outputs.AZURE_CONTAINER_REGISTRY_NAME.value -o tsv)
az acr login --name $ACR_NAME

# 2. Build l'image
docker build -t $ACR_NAME.azurecr.io/medsecure/web:latest -f src/Web/Dockerfile .

# 3. Push vers ACR
docker push $ACR_NAME.azurecr.io/medsecure/web:latest
```

### Déploiement sur App Service

```bash
# Configurer App Service pour utiliser le container
WEB_APP_NAME=$(az deployment sub show --name main --query properties.outputs.AZURE_WEB_APP_NAME.value -o tsv)
RG_NAME=$(az deployment sub show --name main --query properties.outputs.AZURE_RESOURCE_GROUP_NAME.value -o tsv)

az webapp config container set \
  --name $WEB_APP_NAME \
  --resource-group $RG_NAME \
  --docker-custom-image-name $ACR_NAME.azurecr.io/medsecure/web:latest \
  --docker-registry-server-url https://$ACR_NAME.azurecr.io

# Redémarrer l'application
az webapp restart --name $WEB_APP_NAME --resource-group $RG_NAME
```

## ✅ Validation du déploiement

### 1. Vérifier les ressources

```bash
# Lister toutes les ressources
az resource list --resource-group $RG_NAME --output table

# Vérifier que toutes les ressources sont créées :
# - App Service Plan (S1)
# - App Service (Web)
# - SQL Server x2 (Catalog + Identity)
# - Key Vault (Premium)
# - Log Analytics Workspace
# - Application Insights
# - Container Registry (Premium)
```

### 2. Tester le Health Check

```bash
WEB_URL=$(az webapp show --name $WEB_APP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv)

curl https://$WEB_URL/health

# Résultat attendu: 200 OK avec JSON
```

### 3. Vérifier les diagnostics

```bash
# Logs App Service
az webapp log tail --name $WEB_APP_NAME --resource-group $RG_NAME

# Logs Log Analytics (après 5-10 min)
WORKSPACE_ID=$(az deployment sub show --name main --query properties.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID.value -o tsv)

az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AppServiceHTTPLogs | where TimeGenerated > ago(1h) | take 10"
```

### 4. Vérifier la connexion SQL

```bash
SQL_SERVER=$(az deployment sub show --name main --query properties.outputs.AZURE_SQL_CATALOG_SERVER.value -o tsv)

# Test de connexion
sqlcmd -S $SQL_SERVER.database.windows.net -d catalogDatabase -U sqlAdmin -P "$SQL_ADMIN_PASSWORD"

# Vérifier TDE
SELECT name, encryption_state FROM sys.dm_database_encryption_keys
GO
```

## 🔄 Mise à jour de l'infrastructure

```bash
# Redéployer après modification des fichiers Bicep
az deployment sub create \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json \
               sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
               appUserPassword="$APP_USER_PASSWORD" \
               principalId=$PRINCIPAL_ID

# Mode "What-If" pour voir les changements
az deployment sub what-if \
  --location francecentral \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json
```

## 🗑️ Suppression de l'environnement

```bash
# Supprimer le resource group (ATTENTION: supprime TOUT)
az group delete --name rg-medsecure-dev --yes --no-wait

# Avec azd
azd down --purge --force
```

## 🚨 Troubleshooting

### Erreur : "Deployment failed with correlation id"

```bash
# Voir les détails de l'erreur
az deployment sub show --name main --query properties.error

# Voir l'historique des opérations
az deployment operation sub list --name main
```

### Erreur : Key Vault access denied

```bash
# Vérifier les permissions
az keyvault show --name $KV_NAME --query properties.accessPolicies

# Ajouter votre accès
az keyvault set-policy \
  --name $KV_NAME \
  --upn your-email@domain.com \
  --secret-permissions get list set delete
```

### Erreur : SQL Database connection timeout

```bash
# Vérifier le firewall SQL
az sql server firewall-rule list --server $SQL_SERVER --resource-group $RG_NAME

# Ajouter votre IP temporairement (DEV uniquement)
MY_IP=$(curl -s https://ifconfig.me)
az sql server firewall-rule create \
  --server $SQL_SERVER \
  --resource-group $RG_NAME \
  --name AllowMyIP \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP
```

### App Service ne démarre pas

```bash
# Voir les logs en temps réel
az webapp log tail --name $WEB_APP_NAME --resource-group $RG_NAME

# Vérifier les variables d'environnement
az webapp config appsettings list --name $WEB_APP_NAME --resource-group $RG_NAME

# Redémarrer
az webapp restart --name $WEB_APP_NAME --resource-group $RG_NAME
```

## 📊 Monitoring post-déploiement

```bash
# URL Application Insights
AI_NAME=$(az deployment sub show --name main --query properties.outputs.APPLICATIONINSIGHTS_NAME.value -o tsv)
echo "Application Insights: https://portal.azure.com/#resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Insights/components/$AI_NAME"

# URL Log Analytics
echo "Log Analytics: https://portal.azure.com/#resource$WORKSPACE_ID"

# URL App Service
echo "App Service: https://$WEB_URL"
```

## 📚 Ressources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [App Service Deployment](https://learn.microsoft.com/azure/app-service/deploy-best-practices)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)

## ✅ Checklist de déploiement

### Avant le déploiement
- [ ] Azure CLI installé et configuré
- [ ] Subscription sélectionnée
- [ ] Service Principal créé (pour CI/CD)
- [ ] Mots de passe générés et sauvegardés
- [ ] Fichier de paramètres configuré
- [ ] Variable `{subscription-id}` remplacée

### Après le déploiement
- [ ] Toutes les ressources créées
- [ ] Health check répond (200 OK)
- [ ] Connexion SQL fonctionne
- [ ] TDE activé sur SQL Database
- [ ] Logs dans Log Analytics visibles
- [ ] Application Insights reçoit des données
- [ ] Key Vault accessible par App Service
- [ ] Container Registry accessible

### Production uniquement
- [ ] Private Endpoints configurés (SQL + Key Vault)
- [ ] Geo-replication ACR activée
- [ ] Auto-scaling configuré
- [ ] Alertes configurées
- [ ] Backups configurés
- [ ] Plan de reprise d'activité documenté
