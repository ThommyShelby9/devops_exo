# Guide Azure Container Registry (ACR) pour MedSecure

## 📋 Vue d'ensemble

Azure Container Registry (ACR) est le registre privé de containers Docker pour MedSecure, configuré avec les exigences de sécurité HDS.

## 🔐 Configuration de sécurité

### SKU Premium activé

**Fonctionnalités Premium :**
- ✅ **Geo-replication** : Haute disponibilité multi-régions
- ✅ **Private Endpoints** : Isolation réseau totale
- ✅ **Content Trust** : Signatures d'images (Notary)
- ✅ **Customer-managed keys** : Chiffrement avec vos propres clés
- ✅ **Zone redundancy** : Résilience multi-zones

### Politiques de sécurité activées

```bicep
policies: {
  quarantinePolicy: {
    status: 'enabled'  // Images en quarantaine jusqu'au scan
  }
  trustPolicy: {
    type: 'Notary'
    status: 'enabled'  // Seulement images signées
  }
  retentionPolicy: {
    days: 7
    status: 'enabled'  // Nettoyage automatique
  }
}
```

## 🔨 Utilisation dans les pipelines Azure DevOps

### Étape 1 : Build et Push de l'image

**azure-pipelines.yml**
```yaml
stages:
  - stage: BuildAndPush
    jobs:
      - job: Docker
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          # Build .NET application
          - task: DotNetCoreCLI@2
            displayName: 'Build .NET App'
            inputs:
              command: 'publish'
              publishWebProjects: true
              arguments: '--configuration Release --output $(Build.ArtifactStagingDirectory)'

          # Build Docker image
          - task: Docker@2
            displayName: 'Build Docker Image'
            inputs:
              containerRegistry: '$(ACR_SERVICE_CONNECTION)'
              repository: 'medsecure/web'
              command: 'build'
              Dockerfile: 'src/Web/Dockerfile'
              tags: |
                $(Build.BuildId)
                latest

          # Scan image with Trivy (OWASP)
          - task: Bash@3
            displayName: 'Scan Image with Trivy'
            inputs:
              targetType: 'inline'
              script: |
                # Install Trivy
                wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
                sudo apt-get update
                sudo apt-get install trivy

                # Scan image
                trivy image --severity HIGH,CRITICAL --exit-code 1 \
                  $(ACR_LOGIN_SERVER)/medsecure/web:$(Build.BuildId)

          # Push to ACR only if scan passes
          - task: Docker@2
            displayName: 'Push to ACR'
            condition: succeeded()
            inputs:
              containerRegistry: '$(ACR_SERVICE_CONNECTION)'
              repository: 'medsecure/web'
              command: 'push'
              tags: |
                $(Build.BuildId)
                latest
```

### Étape 2 : Service Connection ACR

**Dans Azure DevOps :**
1. Project Settings → Service connections
2. New service connection → Docker Registry
3. Registry type : Azure Container Registry
4. Subscription : Votre souscription Azure
5. Azure Container Registry : Sélectionner votre ACR
6. Service connection name : `ACR_SERVICE_CONNECTION`

### Étape 3 : Variables de pipeline

```yaml
variables:
  ACR_NAME: '$(AZURE_CONTAINER_REGISTRY_NAME)'
  ACR_LOGIN_SERVER: '$(AZURE_CONTAINER_REGISTRY_LOGIN_SERVER)'
  IMAGE_NAME: 'medsecure/web'
  IMAGE_TAG: '$(Build.BuildId)'
```

## 🐳 Dockerfile pour MedSecure (.NET 8)

**src/Web/Dockerfile**
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Web/Web.csproj", "src/Web/"]
COPY ["src/ApplicationCore/ApplicationCore.csproj", "src/ApplicationCore/"]
COPY ["src/Infrastructure/Infrastructure.csproj", "src/Infrastructure/"]

# Restore dependencies
RUN dotnet restore "src/Web/Web.csproj"

# Copy source code
COPY . .

# Build application
WORKDIR "/src/src/Web"
RUN dotnet build "Web.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final

# Security: Run as non-root user
RUN groupadd -r medsecure && useradd -r -g medsecure medsecure
USER medsecure

WORKDIR /app
EXPOSE 8080
EXPOSE 8081

COPY --from=publish /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "Web.dll"]
```

## 🔍 Scan de sécurité avec Trivy

### Rapport de vulnérabilités

```bash
# Scan local
trivy image --severity HIGH,CRITICAL \
  --format json \
  --output trivy-report.json \
  yourregistry.azurecr.io/medsecure/web:latest

# Scan avec seuil de blocage
trivy image --severity CRITICAL --exit-code 1 \
  yourregistry.azurecr.io/medsecure/web:latest
```

### Intégration dans le pipeline

```yaml
- task: PublishTestResults@2
  displayName: 'Publish Trivy Results'
  condition: always()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'trivy-report.xml'
    testRunTitle: 'Trivy Security Scan'
```

## 🚀 Déploiement depuis ACR vers App Service

### Configuration App Service

```bash
# Enable container deployment
az webapp config container set \
  --name medsecure-web \
  --resource-group rg-medsecure \
  --docker-custom-image-name yourregistry.azurecr.io/medsecure/web:latest \
  --docker-registry-server-url https://yourregistry.azurecr.io

# Enable continuous deployment
az webapp deployment container config \
  --name medsecure-web \
  --resource-group rg-medsecure \
  --enable-cd true
```

### Pipeline de déploiement

```yaml
- stage: Deploy
  dependsOn: BuildAndPush
  jobs:
    - deployment: DeployToStaging
      environment: 'staging'
      strategy:
        runOnce:
          deploy:
            steps:
              - task: AzureWebAppContainer@1
                displayName: 'Deploy to Staging Slot'
                inputs:
                  azureSubscription: '$(AZURE_SUBSCRIPTION)'
                  appName: 'medsecure-web'
                  deployToSlotOrASE: true
                  resourceGroupName: 'rg-medsecure'
                  slotName: 'staging'
                  containers: '$(ACR_LOGIN_SERVER)/medsecure/web:$(Build.BuildId)'
```

## 📊 Monitoring et Diagnostics

### Logs disponibles dans Log Analytics

```kusto
// Login events
ContainerRegistryLoginEvents
| where TimeGenerated > ago(24h)
| project TimeGenerated, Identity, LoginServer, ResponseCode

// Repository events (push/pull)
ContainerRegistryRepositoryEvents
| where TimeGenerated > ago(24h)
| project TimeGenerated, OperationName, Repository, Tag, MediaType
| order by TimeGenerated desc
```

### Alertes recommandées

```bicep
// Alert on failed logins
resource acrFailedLoginAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'acr-failed-login-alert'
  properties: {
    severity: 2
    criteria: {
      allOf: [
        {
          metricName: 'FailedLogins'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
        }
      ]
    }
  }
}
```

## 🔑 Authentification

### Managed Identity (Recommandé)

```bash
# L'App Service utilise automatiquement sa Managed Identity
# Aucun credential nécessaire !
```

### Azure CLI (Dev local)

```bash
# Login to ACR
az acr login --name yourregistry

# Pull image
docker pull yourregistry.azurecr.io/medsecure/web:latest
```

### Docker CLI (CI/CD)

```bash
# Using service principal
docker login yourregistry.azurecr.io \
  --username $SP_ID \
  --password $SP_PASSWORD
```

## 🏷️ Stratégie de tagging

### Convention de nommage

```
{registry}.azurecr.io/{repository}:{tag}

Exemples :
- medsecure.azurecr.io/medsecure/web:1.0.0
- medsecure.azurecr.io/medsecure/web:latest
- medsecure.azurecr.io/medsecure/web:dev-123
- medsecure.azurecr.io/medsecure/web:pr-456
```

### Tags recommandés

| Tag | Usage |
|-----|-------|
| `latest` | Dernière version stable |
| `{version}` | Version sémantique (1.0.0) |
| `{buildId}` | ID du build CI (12345) |
| `{branch}-{buildId}` | Build de branche (dev-123) |
| `{pr}-{buildId}` | Pull request (pr-456) |

## ✅ Checklist de sécurité HDS

- [x] **Admin user disabled** : Managed Identity uniquement
- [x] **Quarantine policy** : Scan avant déploiement
- [x] **Content Trust** : Images signées
- [x] **Diagnostics enabled** : Logs vers Log Analytics (90 jours)
- [x] **Premium SKU** : Support Private Endpoints
- [ ] **Private Endpoints** : À configurer en production
- [ ] **Geo-replication** : À activer pour DR
- [ ] **Customer-managed keys** : À configurer si requis

## 📚 Ressources

- [ACR Best Practices](https://learn.microsoft.com/azure/container-registry/container-registry-best-practices)
- [ACR Security](https://learn.microsoft.com/azure/container-registry/container-registry-security)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Docker Content Trust](https://docs.docker.com/engine/security/trust/)
