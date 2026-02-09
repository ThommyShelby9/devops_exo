<#
.SYNOPSIS
    Démarre la plateforme MedSecure en local

.DESCRIPTION
    Ce script lance tous les services nécessaires pour exécuter MedSecure localement :
    - SQL Server (Docker)
    - Azurite (émulateur Azure Storage)
    - Redis (cache)
    - MailHog (SMTP local)
    - Application Web MedSecure
    - API MedSecure (optionnel)

.PARAMETER SkipDocker
    Démarre uniquement l'application sans démarrer les containers Docker

.PARAMETER BuildFirst
    Recompile l'application avant de la démarrer

.PARAMETER WebOnly
    Démarre uniquement l'application Web (pas l'API)

.EXAMPLE
    .\Start-MedSecureLocal.ps1
    Démarre tous les services et l'application

.EXAMPLE
    .\Start-MedSecureLocal.ps1 -SkipDocker
    Démarre uniquement l'application (Docker doit déjà tourner)

.EXAMPLE
    .\Start-MedSecureLocal.ps1 -BuildFirst
    Recompile puis démarre tout
#>

[CmdletBinding()]
param(
    [switch]$SkipDocker,
    [switch]$BuildFirst,
    [switch]$WebOnly
)

$ErrorActionPreference = "Stop"

# ============================================
# Configuration
# ============================================
$projectRoot = $PSScriptRoot
$webProject = Join-Path $projectRoot "src\Web\Web.csproj"
$apiProject = Join-Path $projectRoot "src\PublicApi\PublicApi.csproj"
$dockerCompose = Join-Path $projectRoot "docker-compose.local.yml"

# ============================================
# Functions
# ============================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Header "Vérification des prérequis"

    # Check Docker
    if (-not $SkipDocker) {
        Write-Step "Vérification de Docker..."
        try {
            $dockerVersion = docker --version
            Write-Success "Docker installé : $dockerVersion"
        }
        catch {
            Write-Error "Docker n'est pas installé ou n'est pas démarré"
            Write-Host "Installez Docker Desktop : https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            throw "Docker requis"
        }
    }

    # Check .NET SDK
    Write-Step "Vérification de .NET SDK..."
    try {
        $dotnetVersion = dotnet --version
        Write-Success ".NET SDK installé : $dotnetVersion"
    }
    catch {
        Write-Error ".NET SDK n'est pas installé"
        Write-Host "Installez .NET 8 SDK : https://dotnet.microsoft.com/download" -ForegroundColor Yellow
        throw ".NET SDK requis"
    }

    # Check project files
    Write-Step "Vérification des fichiers du projet..."
    if (-not (Test-Path $webProject)) {
        Write-Error "Projet Web non trouvé : $webProject"
        throw "Fichier projet manquant"
    }
    Write-Success "Projet Web trouvé"

    if (-not $WebOnly -and -not (Test-Path $apiProject)) {
        Write-Warning "Projet API non trouvé : $apiProject (mode WebOnly activé)"
        $script:WebOnly = $true
    }
}

function Start-DockerServices {
    Write-Header "Démarrage des services Docker"

    Write-Step "Arrêt des anciens containers..."
    docker-compose -f $dockerCompose down 2>&1 | Out-Null

    Write-Step "Démarrage des containers Docker..."
    docker-compose -f $dockerCompose up -d

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Échec du démarrage des containers Docker"
        throw "Docker compose failed"
    }

    Write-Success "Containers Docker démarrés"

    # Wait for SQL Server to be ready
    Write-Step "Attente du démarrage de SQL Server..."
    $maxWait = 60
    $waited = 0
    $ready = $false

    while ($waited -lt $maxWait -and -not $ready) {
        try {
            $result = docker exec medsecure-sql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "MedSecure2024!" -Q "SELECT 1" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
            }
        }
        catch {
            # Continue waiting
        }

        if (-not $ready) {
            Start-Sleep -Seconds 2
            $waited += 2
            Write-Host "." -NoNewline
        }
    }

    Write-Host ""

    if ($ready) {
        Write-Success "SQL Server prêt"
    }
    else {
        Write-Warning "SQL Server n'est peut-être pas prêt (timeout après ${maxWait}s)"
    }
}

function Initialize-Database {
    Write-Header "Initialisation de la base de données"

    Write-Step "Application des migrations Entity Framework..."

    Push-Location (Join-Path $projectRoot "src\Web")

    try {
        # Drop existing databases
        Write-Step "Suppression des anciennes bases de données..."
        dotnet ef database drop --force --context CatalogContext 2>&1 | Out-Null
        dotnet ef database drop --force --context AppIdentityDbContext 2>&1 | Out-Null

        # Update databases
        Write-Step "Création de la base de données Catalog..."
        dotnet ef database update --context CatalogContext

        Write-Step "Création de la base de données Identity..."
        dotnet ef database update --context AppIdentityDbContext

        Write-Success "Bases de données initialisées"
    }
    catch {
        Write-Error "Échec de l'initialisation de la base de données : $_"
        throw
    }
    finally {
        Pop-Location
    }
}

function Build-Application {
    Write-Header "Compilation de l'application"

    Write-Step "Restauration des packages NuGet..."
    dotnet restore

    Write-Step "Compilation du projet Web..."
    dotnet build $webProject --configuration Debug --no-restore

    if (-not $WebOnly) {
        Write-Step "Compilation de l'API..."
        dotnet build $apiProject --configuration Debug --no-restore
    }

    Write-Success "Compilation terminée"
}

function Start-Application {
    Write-Header "Démarrage de l'application MedSecure"

    # Start Web
    Write-Step "Démarrage de l'application Web..."
    Write-Host ""
    Write-Host "Application Web : https://localhost:44315" -ForegroundColor Green
    if (-not $WebOnly) {
        Write-Host "API : https://localhost:5099" -ForegroundColor Green
    }
    Write-Host "MailHog UI : http://localhost:8025" -ForegroundColor Green
    Write-Host ""
    Write-Host "Appuyez sur Ctrl+C pour arrêter l'application" -ForegroundColor Yellow
    Write-Host ""

    if ($WebOnly) {
        # Start only Web
        dotnet run --project $webProject --no-build
    }
    else {
        # Start both Web and API in separate windows
        Start-Process pwsh -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; dotnet run --project '$apiProject' --no-build"
        Start-Sleep -Seconds 2
        dotnet run --project $webProject --no-build
    }
}

# ============================================
# Main Execution
# ============================================

try {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   MedSecure Platform - Démarrage Local                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Step 1: Prerequisites
    Test-Prerequisites

    # Step 2: Docker services
    if (-not $SkipDocker) {
        Start-DockerServices
    }
    else {
        Write-Warning "Docker services skipped (--SkipDocker)"
    }

    # Step 3: Build
    if ($BuildFirst) {
        Build-Application
    }
    else {
        Write-Warning "Compilation skipped (utilisez -BuildFirst pour recompiler)"
    }

    # Step 4: Database
    if (-not $SkipDocker) {
        Initialize-Database
    }

    # Step 5: Start application
    Start-Application
}
catch {
    Write-Error "Erreur lors du démarrage : $_"
    Write-Host ""
    Write-Host "Pour nettoyer et redémarrer :" -ForegroundColor Yellow
    Write-Host "  docker-compose -f docker-compose.local.yml down -v" -ForegroundColor White
    Write-Host "  .\Start-MedSecureLocal.ps1 -BuildFirst" -ForegroundColor White
    exit 1
}
