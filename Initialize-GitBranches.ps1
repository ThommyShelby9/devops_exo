<#
.SYNOPSIS
    Initialise les branches Git pour le projet MedSecure

.DESCRIPTION
    Ce script :
    - Crée les branches principales (main, develop)
    - Pousse les branches vers le remote
    - Affiche les instructions pour configurer les protections de branches

.PARAMETER Remote
    Nom du remote (par défaut: origin)

.PARAMETER Push
    Pousser les branches vers le remote

.EXAMPLE
    .\Initialize-GitBranches.ps1 -Push
#>

[CmdletBinding()]
param(
    [string]$Remote = "origin",
    [switch]$Push
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   MedSecure - Initialisation des branches Git             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ============================================
# État actuel
# ============================================
Write-Header "État actuel du repository"

$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Info "Branche actuelle : $currentBranch"

Write-Host ""
Write-Host "Branches locales :" -ForegroundColor Cyan
git branch

Write-Host ""
Write-Host "Branches remote :" -ForegroundColor Cyan
git branch -r

# ============================================
# Vérifier que develop existe
# ============================================
Write-Header "Vérification des branches"

$developExists = git branch --list develop
if ($developExists) {
    Write-Success "Branche 'develop' existe"
} else {
    Write-Info "Création de la branche 'develop'..."
    git checkout -b develop
    Write-Success "Branche 'develop' créée"
}

# Retourner sur main
git checkout main 2>&1 | Out-Null
Write-Success "Branche 'main' existe"

# ============================================
# Push vers remote (si demandé)
# ============================================
if ($Push) {
    Write-Header "Push vers le remote"

    Write-Info "Push de la branche 'main'..."
    git push -u $Remote main
    Write-Success "Branche 'main' poussée vers $Remote"

    Write-Info "Push de la branche 'develop'..."
    git push -u $Remote develop
    Write-Success "Branche 'develop' poussée vers $Remote"
}
else {
    Write-Host ""
    Write-Host "Pour pousser les branches vers le remote, exécutez :" -ForegroundColor Yellow
    Write-Host "  git push -u $Remote main" -ForegroundColor White
    Write-Host "  git push -u $Remote develop" -ForegroundColor White
    Write-Host ""
    Write-Host "Ou relancez ce script avec : " -ForegroundColor Yellow
    Write-Host "  .\Initialize-GitBranches.ps1 -Push" -ForegroundColor White
}

# ============================================
# Instructions pour la protection des branches
# ============================================
Write-Header "Configuration des protections de branches"

Write-Host ""
Write-Host "Étapes suivantes pour configurer les protections de branches :" -ForegroundColor Cyan
Write-Host ""

if (git remote get-url $Remote 2>$null | Select-String "github.com") {
    Write-Host "📌 GitHub - Configuration des protections :" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Aller sur : https://github.com/<org>/<repo>/settings/branches" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Protéger la branche 'main' :" -ForegroundColor White
    Write-Host "   ✓ Require pull request reviews before merging (2 approvals)" -ForegroundColor Gray
    Write-Host "   ✓ Require status checks to pass before merging:" -ForegroundColor Gray
    Write-Host "     - build-and-test" -ForegroundColor Gray
    Write-Host "     - sonarcloud-analysis" -ForegroundColor Gray
    Write-Host "     - security-scan" -ForegroundColor Gray
    Write-Host "   ✓ Require conversation resolution before merging" -ForegroundColor Gray
    Write-Host "   ✓ Require signed commits (recommandé)" -ForegroundColor Gray
    Write-Host "   ✓ Include administrators" -ForegroundColor Gray
    Write-Host "   ✓ Restrict who can push to matching branches (Release Managers)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Protéger la branche 'develop' :" -ForegroundColor White
    Write-Host "   ✓ Require pull request reviews before merging (1 approval)" -ForegroundColor Gray
    Write-Host "   ✓ Require status checks to pass before merging:" -ForegroundColor Gray
    Write-Host "     - build-and-test" -ForegroundColor Gray
    Write-Host "     - sonarcloud-analysis" -ForegroundColor Gray
    Write-Host "   ✓ Require conversation resolution before merging" -ForegroundColor Gray
}
elseif (git remote get-url $Remote 2>$null | Select-String "dev.azure.com") {
    Write-Host "📌 Azure DevOps - Configuration des protections :" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Aller sur : Project Settings > Repos > Policies" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Branche 'main' :" -ForegroundColor White
    Write-Host "   ✓ Require a minimum number of reviewers: 2" -ForegroundColor Gray
    Write-Host "   ✓ Check for linked work items: Required" -ForegroundColor Gray
    Write-Host "   ✓ Check for comment resolution: Required" -ForegroundColor Gray
    Write-Host "   ✓ Build validation:" -ForegroundColor Gray
    Write-Host "     - azure-pipelines.yml" -ForegroundColor Gray
    Write-Host "   ✓ Status check: Required (SonarCloud, Security)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Branche 'develop' :" -ForegroundColor White
    Write-Host "   ✓ Require a minimum number of reviewers: 1" -ForegroundColor Gray
    Write-Host "   ✓ Build validation: azure-pipelines.yml" -ForegroundColor Gray
}
else {
    Write-Host "📌 Configuration manuelle nécessaire sur votre plateforme Git" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Consultez : docs/GIT_WORKFLOW.md pour les détails" -ForegroundColor White
}

# ============================================
# Résumé
# ============================================
Write-Header "Résumé de la configuration"

Write-Host ""
Write-Host "Branches créées :" -ForegroundColor Cyan
Write-Host "  ✓ main    - Production" -ForegroundColor Green
Write-Host "  ✓ develop - Développement" -ForegroundColor Green

Write-Host ""
Write-Host "Structure de branching :" -ForegroundColor Cyan
Write-Host ""
Write-Host "  main (production)" -ForegroundColor White
Write-Host "    └─► release/vX.Y (staging)" -ForegroundColor White
Write-Host "         └─► develop (intégration)" -ForegroundColor White
Write-Host "              ├─► feature/US-XX-description" -ForegroundColor Gray
Write-Host "              ├─► bugfix/description" -ForegroundColor Gray
Write-Host "              └─► hotfix/description" -ForegroundColor Gray

Write-Host ""
Write-Host "Documentation :" -ForegroundColor Cyan
Write-Host "  • Workflow Git complet : docs/GIT_WORKFLOW.md" -ForegroundColor White
Write-Host "  • Guide rapide         : docs/GIT_QUICK_START.md" -ForegroundColor White
Write-Host "  • Guide contribution   : CONTRIBUTING.md" -ForegroundColor White

Write-Host ""
Write-Host "Prochaines étapes :" -ForegroundColor Cyan
Write-Host "  1. Pousser les branches vers le remote (si pas encore fait)" -ForegroundColor White
Write-Host "  2. Configurer les protections de branches (voir ci-dessus)" -ForegroundColor White
Write-Host "  3. Installer les hooks Git : .\Setup-GitHooks.ps1" -ForegroundColor White
Write-Host "  4. Former l'équipe au workflow Git" -ForegroundColor White

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ Branches Git initialisées avec succès !               ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
