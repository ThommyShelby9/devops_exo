# MedSecure - Script de déploiement automatisé
# Usage: .\scripts\deploy.ps1 -Environment dev|staging|prod

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure,

    [Parameter(Mandatory=$false)]
    [switch]$SkipApplication
)

$ErrorActionPreference = "Stop"

# Couleurs pour les messages
function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠️  $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "❌ $args" -ForegroundColor Red }

Write-Info "🚀 Déploiement MedSecure - Environnement: $Environment"
Write-Info "=================================================="

# 1. Vérifier les prérequis
Write-Info "Vérification des prérequis..."

try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Success "Azure CLI: $($azVersion.'azure-cli')"
} catch {
    Write-Error "Azure CLI n'est pas installé. Installez-le depuis https://aka.ms/installazurecli"
    exit 1
}

try {
    $dotnetVersion = dotnet --version
    Write-Success ".NET SDK: $dotnetVersion"
} catch {
    Write-Error ".NET SDK 8.0 n'est pas installé. Installez-le depuis https://dotnet.microsoft.com/download"
    exit 1
}

# 2. Login Azure
Write-Info "Vérification de la connexion Azure..."
$account = az account show --output json 2>$null | ConvertFrom-Json

if (-not $account) {
    Write-Warning "Non connecté à Azure. Connexion en cours..."
    az login
    $account = az account show --output json | ConvertFrom-Json
}

Write-Success "Connecté à Azure - Subscription: $($account.name)"

# 3. Configuration de l'environnement
$location = "francecentral"
$envName = "medsecure-$Environment"
$parametersFile = "infra/main.parameters.$Environment.json"

if (-not (Test-Path $parametersFile)) {
    Write-Error "Fichier de paramètres introuvable: $parametersFile"
    exit 1
}

# 4. Générer ou récupérer les secrets
Write-Info "Gestion des secrets..."

function Get-OrGeneratePassword {
    param([string]$SecretName)

    $kvName = "kv-medsecure-deploy"

    # Vérifier si le Key Vault existe
    $kvExists = az keyvault show --name $kvName --output json 2>$null

    if ($kvExists) {
        # Récupérer le secret existant
        $secret = az keyvault secret show --vault-name $kvName --name $SecretName --query value -o tsv 2>$null

        if ($secret) {
            Write-Success "Secret '$SecretName' récupéré depuis Key Vault"
            return $secret
        }
    }

    # Générer un nouveau mot de passe
    $password = -join ((33..126) | Get-Random -Count 24 | ForEach-Object {[char]$_})
    Write-Warning "Nouveau mot de passe généré pour '$SecretName'"
    Write-Warning "SAUVEGARDEZ CE MOT DE PASSE: $password"

    return $password
}

$sqlAdminPassword = Get-OrGeneratePassword -SecretName "sqlAdminPassword-$Environment"
$appUserPassword = Get-OrGeneratePassword -SecretName "appUserPassword-$Environment"

# 5. Obtenir le Principal ID
$principalId = az ad signed-in-user show --query id -o tsv
Write-Success "Principal ID: $principalId"

# 6. Déployer l'infrastructure
if (-not $SkipInfrastructure) {
    Write-Info "Déploiement de l'infrastructure..."

    $deploymentName = "medsecure-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    if ($WhatIf) {
        Write-Info "Mode What-If activé - Aperçu des changements..."

        az deployment sub what-if `
            --location $location `
            --name $deploymentName `
            --template-file infra/main.bicep `
            --parameters "@$parametersFile" `
                         sqlAdminPassword="$sqlAdminPassword" `
                         appUserPassword="$appUserPassword" `
                         principalId="$principalId"

        Write-Info "Mode What-If terminé. Aucun changement appliqué."
        exit 0
    }

    Write-Info "Déploiement en cours... (cela peut prendre 10-15 minutes)"

    $deployment = az deployment sub create `
        --location $location `
        --name $deploymentName `
        --template-file infra/main.bicep `
        --parameters "@$parametersFile" `
                     sqlAdminPassword="$sqlAdminPassword" `
                     appUserPassword="$appUserPassword" `
                     principalId="$principalId" `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Le déploiement a échoué. Vérifiez les logs Azure."
        exit 1
    }

    Write-Success "Infrastructure déployée avec succès!"

    # Afficher les outputs
    Write-Info "`nOutputs du déploiement:"
    $deployment.properties.outputs | Format-Table -AutoSize

} else {
    Write-Warning "Déploiement de l'infrastructure ignoré (--SkipInfrastructure)"

    # Récupérer le dernier déploiement
    $deployment = az deployment sub show --name "main" --output json | ConvertFrom-Json
}

# 7. Déployer l'application
if (-not $SkipApplication) {
    Write-Info "`nDéploiement de l'application..."

    $acrName = $deployment.properties.outputs.AZURE_CONTAINER_REGISTRY_NAME.value
    $acrLoginServer = $deployment.properties.outputs.AZURE_CONTAINER_REGISTRY_LOGIN_SERVER.value
    $webAppName = $deployment.properties.outputs.AZURE_WEB_APP_NAME.value
    $rgName = $deployment.properties.outputs.AZURE_RESOURCE_GROUP_NAME.value

    # Login ACR
    Write-Info "Connexion à Azure Container Registry..."
    az acr login --name $acrName

    # Build l'image Docker
    Write-Info "Build de l'image Docker..."
    $imageName = "$acrLoginServer/medsecure/web"
    $imageTag = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    docker build -t "${imageName}:${imageTag}" -t "${imageName}:latest" -f src/Web/Dockerfile .

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build Docker a échoué"
        exit 1
    }

    # Push vers ACR
    Write-Info "Push vers Azure Container Registry..."
    docker push "${imageName}:${imageTag}"
    docker push "${imageName}:latest"

    # Configurer App Service
    Write-Info "Configuration de l'App Service..."
    az webapp config container set `
        --name $webAppName `
        --resource-group $rgName `
        --docker-custom-image-name "${imageName}:${imageTag}" `
        --docker-registry-server-url "https://$acrLoginServer"

    # Redémarrer l'application
    Write-Info "Redémarrage de l'application..."
    az webapp restart --name $webAppName --resource-group $rgName

    Write-Success "Application déployée avec succès!"

    # Attendre le démarrage
    Write-Info "Attente du démarrage de l'application (30s)..."
    Start-Sleep -Seconds 30

    # Tester le health check
    $webUrl = "https://$webAppName.azurewebsites.net"
    Write-Info "Test du health check: $webUrl/health"

    try {
        $response = Invoke-WebRequest -Uri "$webUrl/health" -UseBasicParsing

        if ($response.StatusCode -eq 200) {
            Write-Success "Health check OK - Application en cours d'exécution!"
        } else {
            Write-Warning "Health check a retourné: $($response.StatusCode)"
        }
    } catch {
        Write-Warning "Health check a échoué. L'application peut mettre quelques minutes à démarrer."
        Write-Info "URL de l'application: $webUrl"
    }

} else {
    Write-Warning "Déploiement de l'application ignoré (--SkipApplication)"
}

# 8. Résumé
Write-Info "`n=================================================="
Write-Success "🎉 Déploiement terminé avec succès!"
Write-Info "=================================================="

if ($deployment) {
    $outputs = $deployment.properties.outputs

    Write-Info "`n📊 Ressources déployées:"
    Write-Host "  • Resource Group:      $($outputs.AZURE_RESOURCE_GROUP_NAME.value)" -ForegroundColor White
    Write-Host "  • App Service:         https://$($outputs.AZURE_WEB_APP_NAME.value).azurewebsites.net" -ForegroundColor White
    Write-Host "  • Key Vault:           $($outputs.AZURE_KEY_VAULT_NAME.value)" -ForegroundColor White
    Write-Host "  • Log Analytics:       $($outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME.value)" -ForegroundColor White
    Write-Host "  • App Insights:        $($outputs.APPLICATIONINSIGHTS_NAME.value)" -ForegroundColor White
    Write-Host "  • Container Registry:  $($outputs.AZURE_CONTAINER_REGISTRY_NAME.value)" -ForegroundColor White

    Write-Info "`n🔗 Liens utiles:"
    Write-Host "  • Application:         https://$($outputs.AZURE_WEB_APP_NAME.value).azurewebsites.net" -ForegroundColor Cyan
    Write-Host "  • Health Check:        https://$($outputs.AZURE_WEB_APP_NAME.value).azurewebsites.net/health" -ForegroundColor Cyan
    Write-Host "  • Azure Portal:        https://portal.azure.com/#resource$($outputs.AZURE_RESOURCE_GROUP_ID.value)" -ForegroundColor Cyan
}

Write-Info "`n✅ Prochaines étapes:"
Write-Host "  1. Vérifier l'application: $webUrl" -ForegroundColor Yellow
Write-Host "  2. Consulter les logs: az webapp log tail --name $webAppName --resource-group $rgName" -ForegroundColor Yellow
Write-Host "  3. Configurer les alertes de monitoring" -ForegroundColor Yellow
Write-Host "  4. Configurer les Private Endpoints (PROD)" -ForegroundColor Yellow
