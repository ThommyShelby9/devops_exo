<#
.SYNOPSIS
    Manage Azure App Service deployment slots for Blue/Green deployments

.DESCRIPTION
    This script provides utilities to:
    - Swap deployment slots (Blue/Green deployment)
    - Rollback to previous version
    - Check slot status
    - View deployment history

.PARAMETER Action
    The action to perform: Swap, Rollback, Status, History

.PARAMETER Environment
    Target environment: DEV, STAGING, PROD

.PARAMETER ResourceGroupName
    Azure Resource Group name

.PARAMETER AppServiceName
    Azure App Service name

.PARAMETER SourceSlot
    Source slot name (default: staging)

.PARAMETER TargetSlot
    Target slot name (default: production)

.EXAMPLE
    .\Manage-DeploymentSlots.ps1 -Action Swap -Environment PROD
    Swaps staging slot to production

.EXAMPLE
    .\Manage-DeploymentSlots.ps1 -Action Rollback -Environment PROD
    Rolls back production to previous version (staging slot)

.EXAMPLE
    .\Manage-DeploymentSlots.ps1 -Action Status -Environment STAGING
    Shows current status of deployment slots

.NOTES
    Author: MedSecure DevOps Team
    Version: 1.0.0
    HDS Compliance: All actions are logged for audit trail
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Swap', 'Rollback', 'Status', 'History', 'SwapWithPreview', 'CompleteSwap', 'CancelSwap')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [ValidateSet('DEV', 'STAGING', 'PROD')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$AppServiceName,

    [Parameter(Mandatory = $false)]
    [string]$SourceSlot = 'staging',

    [Parameter(Mandatory = $false)]
    [string]$TargetSlot = 'production',

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ============================================
# Configuration
# ============================================

$ErrorActionPreference = 'Stop'

# Environment-specific configuration
$envConfig = @{
    'DEV' = @{
        ResourceGroup = 'rg-medsecure-dev'
        AppService = 'app-medsecure-dev'
    }
    'STAGING' = @{
        ResourceGroup = 'rg-medsecure-staging'
        AppService = 'app-medsecure-staging'
    }
    'PROD' = @{
        ResourceGroup = 'rg-medsecure-prod'
        AppService = 'app-medsecure-prod'
    }
}

# Use provided names or default from config
if (-not $ResourceGroupName) {
    $ResourceGroupName = $envConfig[$Environment].ResourceGroup
}
if (-not $AppServiceName) {
    $AppServiceName = $envConfig[$Environment].AppService
}

# ============================================
# Functions
# ============================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }

    $emoji = switch ($Level) {
        'Info' { 'ℹ️ ' }
        'Warning' { '⚠️ ' }
        'Error' { '❌' }
        'Success' { '✅' }
    }

    Write-Host "[$timestamp] $emoji $Message" -ForegroundColor $color

    # Append to audit log
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Action = $Action
        Environment = $Environment
        ResourceGroup = $ResourceGroupName
        AppService = $AppServiceName
        User = $env:USERNAME
    }

    $logPath = Join-Path $PSScriptRoot "../logs/deployment-$(Get-Date -Format 'yyyy-MM-dd').json"
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logPath
}

function Test-AzureConnection {
    Write-Log "Checking Azure connection..." -Level Info

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Log "Not logged in to Azure. Running 'az login'..." -Level Warning
        az login
        $context = Get-AzContext
    }

    Write-Log "Connected to Azure subscription: $($context.Subscription.Name)" -Level Success
}

function Get-SlotStatus {
    Write-Log "Fetching deployment slot status..." -Level Info

    $webapp = az webapp show `
        --name $AppServiceName `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json

    $slots = az webapp deployment slot list `
        --name $AppServiceName `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " 📊 Deployment Slot Status - $Environment" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "App Service: $AppServiceName" -ForegroundColor White
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host ""

    # Production slot
    Write-Host "🔵 PRODUCTION (Live Traffic)" -ForegroundColor Green
    Write-Host "   URL: https://$($webapp.defaultHostName)"
    Write-Host "   State: $($webapp.state)"
    Write-Host "   Last Modified: $($webapp.lastModifiedTimeUtc)"
    Write-Host ""

    # Staging slots
    foreach ($slot in $slots) {
        Write-Host "🟢 SLOT: $($slot.name)" -ForegroundColor Yellow
        Write-Host "   URL: https://$($slot.defaultHostName)"
        Write-Host "   State: $($slot.state)"
        Write-Host "   Last Modified: $($slot.lastModifiedTimeUtc)"
        Write-Host ""
    }

    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-SlotSwap {
    param(
        [bool]$WithPreview = $false
    )

    Write-Log "Initiating slot swap: $SourceSlot → $TargetSlot" -Level Info

    if (-not $Force) {
        Write-Host ""
        Write-Host "⚠️  WARNING: You are about to swap deployment slots!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Environment: $Environment" -ForegroundColor White
        Write-Host "Source Slot: $SourceSlot" -ForegroundColor White
        Write-Host "Target Slot: $TargetSlot" -ForegroundColor White
        Write-Host ""
        $confirm = Read-Host "Type 'YES' to confirm swap"
        if ($confirm -ne 'YES') {
            Write-Log "Swap cancelled by user" -Level Warning
            return
        }
    }

    try {
        if ($WithPreview) {
            Write-Log "Starting swap with preview..." -Level Info

            az webapp deployment slot swap `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --slot $SourceSlot `
                --target-slot $TargetSlot `
                --action preview

            Write-Log "Swap preview started. Review the changes and run 'CompleteSwap' to finish." -Level Success
        }
        else {
            Write-Log "Performing direct slot swap..." -Level Info

            az webapp deployment slot swap `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --slot $SourceSlot `
                --target-slot $TargetSlot

            Write-Log "Slot swap completed successfully!" -Level Success
        }

        # Run health check
        Start-Sleep -Seconds 10
        Test-SlotHealth -SlotName $TargetSlot
    }
    catch {
        Write-Log "Swap failed: $_" -Level Error
        throw
    }
}

function Complete-SlotSwapPreview {
    Write-Log "Completing swap preview..." -Level Info

    try {
        az webapp deployment slot swap `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --slot $SourceSlot `
            --target-slot $TargetSlot `
            --action swap

        Write-Log "Swap completed successfully!" -Level Success
    }
    catch {
        Write-Log "Failed to complete swap: $_" -Level Error
        throw
    }
}

function Stop-SlotSwapPreview {
    Write-Log "Cancelling swap preview..." -Level Info

    try {
        az webapp deployment slot swap `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --slot $SourceSlot `
            --action reset

        Write-Log "Swap preview cancelled" -Level Success
    }
    catch {
        Write-Log "Failed to cancel swap: $_" -Level Error
        throw
    }
}

function Invoke-Rollback {
    Write-Log "Initiating rollback..." -Level Warning

    Write-Host ""
    Write-Host "🔄 ROLLBACK PROCEDURE" -ForegroundColor Red
    Write-Host ""
    Write-Host "This will swap production back to the staging slot content."
    Write-Host "Production → Staging"
    Write-Host "Staging → Production (rollback)"
    Write-Host ""

    if (-not $Force) {
        $confirm = Read-Host "Type 'ROLLBACK' to confirm"
        if ($confirm -ne 'ROLLBACK') {
            Write-Log "Rollback cancelled" -Level Warning
            return
        }
    }

    # Swap back: production → staging
    $originalSource = $SourceSlot
    $originalTarget = $TargetSlot

    $script:SourceSlot = $originalTarget  # production
    $script:TargetSlot = $originalSource  # staging

    Invoke-SlotSwap -WithPreview $false

    Write-Log "Rollback completed. Production reverted to previous version." -Level Success
}

function Test-SlotHealth {
    param([string]$SlotName)

    Write-Log "Running health check on $SlotName slot..." -Level Info

    $url = if ($SlotName -eq 'production') {
        "https://$AppServiceName.azurewebsites.net/health"
    }
    else {
        "https://$AppServiceName-$SlotName.azurewebsites.net/health"
    }

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            Write-Log "Health check PASSED (HTTP $($response.StatusCode))" -Level Success
        }
        else {
            Write-Log "Health check returned HTTP $($response.StatusCode)" -Level Warning
        }
    }
    catch {
        Write-Log "Health check FAILED: $_" -Level Error
    }
}

function Get-DeploymentHistory {
    Write-Log "Fetching deployment history..." -Level Info

    $deployments = az webapp deployment list `
        --name $AppServiceName `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " 📜 Deployment History - Last 10 Deployments" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $deployments | Select-Object -First 10 | ForEach-Object {
        $status = if ($_.status -eq 4) { "✅ Success" } else { "❌ Failed" }
        Write-Host "$status | $($_.received_time) | $($_.author) | $($_.message)"
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================
# Main Script
# ============================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   MedSecure - Deployment Slot Manager                    ║" -ForegroundColor Cyan
Write-Host "║   Blue/Green Deployment Utility                          ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting action: $Action for environment: $Environment" -Level Info

# Check Azure connection
Test-AzureConnection

# Execute action
switch ($Action) {
    'Status' {
        Get-SlotStatus
    }
    'Swap' {
        Invoke-SlotSwap -WithPreview $false
    }
    'SwapWithPreview' {
        Invoke-SlotSwap -WithPreview $true
    }
    'CompleteSwap' {
        Complete-SlotSwapPreview
    }
    'CancelSwap' {
        Stop-SlotSwapPreview
    }
    'Rollback' {
        Invoke-Rollback
    }
    'History' {
        Get-DeploymentHistory
    }
}

Write-Log "Action completed: $Action" -Level Success
Write-Host ""
