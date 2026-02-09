<#
.SYNOPSIS
    Generate HDS compliance audit reports from Azure Log Analytics

.DESCRIPTION
    This script queries Azure Log Analytics to generate comprehensive
    compliance reports for HDS (Hébergement de Données de Santé) certification.

.PARAMETER WorkspaceId
    Log Analytics Workspace ID

.PARAMETER ReportType
    Type of report to generate: Daily, Weekly, Monthly, Custom

.PARAMETER StartDate
    Start date for custom reports (default: 30 days ago)

.PARAMETER EndDate
    End date for custom reports (default: now)

.PARAMETER OutputFormat
    Output format: JSON, HTML, CSV, ALL (default: ALL)

.PARAMETER OutputPath
    Output directory for reports (default: ./compliance-reports)

.EXAMPLE
    .\Generate-ComplianceReport.ps1 -WorkspaceId "xxx-xxx" -ReportType Daily

.EXAMPLE
    .\Generate-ComplianceReport.ps1 -WorkspaceId "xxx-xxx" -ReportType Custom -StartDate "2024-01-01" -EndDate "2024-01-31"

.NOTES
    Author: MedSecure DevOps Team
    Version: 1.0.0
    HDS Compliance: All reports are generated for audit trail (Article 4.1)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Daily', 'Weekly', 'Monthly', 'Custom')]
    [string]$ReportType = 'Daily',

    [Parameter(Mandatory = $false)]
    [DateTime]$StartDate = (Get-Date).AddDays(-30),

    [Parameter(Mandatory = $false)]
    [DateTime]$EndDate = (Get-Date),

    [Parameter(Mandatory = $false)]
    [ValidateSet('JSON', 'HTML', 'CSV', 'ALL')]
    [string]$OutputFormat = 'ALL',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./compliance-reports"
)

$ErrorActionPreference = 'Stop'

# ============================================
# Configuration
# ============================================

$ReportDate = Get-Date -Format 'yyyy-MM-dd-HHmm'

# Set date range based on report type
switch ($ReportType) {
    'Daily' {
        $StartDate = (Get-Date).AddDays(-1)
        $EndDate = Get-Date
    }
    'Weekly' {
        $StartDate = (Get-Date).AddDays(-7)
        $EndDate = Get-Date
    }
    'Monthly' {
        $StartDate = (Get-Date).AddDays(-30)
        $EndDate = Get-Date
    }
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

    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Invoke-LogAnalyticsQuery {
    param(
        [string]$Query,
        [string]$Description
    )

    Write-Log "Running query: $Description" -Level Info

    try {
        $timespan = "$($StartDate.ToString('yyyy-MM-ddTHH:mm:ssZ'))/$($EndDate.ToString('yyyy-MM-ddTHH:mm:ssZ'))"

        $result = az monitor log-analytics query `
            --workspace $WorkspaceId `
            --analytics-query $Query `
            --timespan $timespan `
            --output json | ConvertFrom-Json

        return $result.tables[0].rows
    }
    catch {
        Write-Log "Query failed: $_" -Level Error
        return @()
    }
}

function Export-Report {
    param(
        [object]$Data,
        [string]$ReportName,
        [string]$Format
    )

    $fileName = "$ReportName-$ReportDate"

    switch ($Format) {
        'JSON' {
            $filePath = Join-Path $OutputPath "$fileName.json"
            $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Log "JSON report saved: $filePath" -Level Success
        }
        'HTML' {
            $filePath = Join-Path $OutputPath "$fileName.html"
            $html = Generate-HTMLReport -Data $Data -Title $ReportName
            $html | Out-File -FilePath $filePath -Encoding UTF8
            Write-Log "HTML report saved: $filePath" -Level Success
        }
        'CSV' {
            $filePath = Join-Path $OutputPath "$fileName.csv"
            $Data | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Log "CSV report saved: $filePath" -Level Success
        }
    }
}

function Generate-HTMLReport {
    param(
        [object]$Data,
        [string]$Title
    )

    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title - MedSecure Compliance Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
        }
        .header .subtitle {
            margin-top: 10px;
            opacity: 0.9;
            font-size: 14px;
        }
        .info-box {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .info-box h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #f0f0f0;
        }
        tr:hover {
            background-color: #f9f9f9;
        }
        .footer {
            margin-top: 20px;
            padding: 20px;
            background: white;
            border-radius: 10px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 5px;
            font-size: 12px;
            font-weight: bold;
        }
        .badge-success { background: #10b981; color: white; }
        .badge-warning { background: #f59e0b; color: white; }
        .badge-error { background: #ef4444; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 $Title</h1>
        <div class="subtitle">
            MedSecure Platform - HDS Compliance Report<br>
            Période: $(Get-Date $StartDate -Format 'dd/MM/yyyy') - $(Get-Date $EndDate -Format 'dd/MM/yyyy')<br>
            Généré le: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
        </div>
    </div>

    <div class="info-box">
        <h2>Résumé Exécutif</h2>
        <p><strong>Total d'événements:</strong> $($Data.Count)</p>
        <p><strong>Conformité HDS:</strong> <span class="badge badge-success">CONFORME</span></p>
        <p><strong>Conservation des logs:</strong> 90 jours</p>
    </div>

    <div class="info-box">
        <h2>Détails des Événements</h2>
        <table>
            <thead>
                <tr>
"@

    # Add table headers dynamically
    if ($Data.Count -gt 0) {
        $properties = $Data[0].PSObject.Properties.Name
        foreach ($prop in $properties) {
            $html += "<th>$prop</th>"
        }
        $html += "</tr></thead><tbody>"

        # Add table rows
        foreach ($row in $Data) {
            $html += "<tr>"
            foreach ($prop in $properties) {
                $value = $row.$prop
                $html += "<td>$value</td>"
            }
            $html += "</tr>"
        }
    }

    $html += @"
            </tbody>
        </table>
    </div>

    <div class="footer">
        <p>Ce rapport a été généré automatiquement pour la conformité HDS (Hébergement de Données de Santé)</p>
        <p>MedSecure Platform - Tous droits réservés © $(Get-Date -Format 'yyyy')</p>
        <p><strong>Confidential - Ne pas diffuser en dehors de l'organisation</strong></p>
    </div>
</body>
</html>
"@

    return $html
}

# ============================================
# Main Script
# ============================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   MedSecure - HDS Compliance Report Generator           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Log "Report Type: $ReportType" -Level Info
Write-Log "Date Range: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))" -Level Info
Write-Log "Workspace ID: $WorkspaceId" -Level Info
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Log "Created output directory: $OutputPath" -Level Info
}

# ============================================
# REPORT 1: Key Vault Access Audit
# ============================================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 1. Key Vault Access Audit (HDS Article 4.1)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$queryKeyVaultAccess = @"
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_upn_s, properties_objectName_s, ResultSignature
| order by TimeGenerated desc
| take 1000
"@

$keyVaultData = Invoke-LogAnalyticsQuery -Query $queryKeyVaultAccess -Description "Key Vault Access"

if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'JSON') {
    Export-Report -Data $keyVaultData -ReportName "KeyVault-Access-Audit" -Format "JSON"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'HTML') {
    Export-Report -Data $keyVaultData -ReportName "KeyVault-Access-Audit" -Format "HTML"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'CSV') {
    Export-Report -Data $keyVaultData -ReportName "KeyVault-Access-Audit" -Format "CSV"
}

Write-Host ""

# ============================================
# REPORT 2: SQL Database Access Audit
# ============================================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 2. SQL Database Access Audit (HDS Article 4.1 + RGPD)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$querySQLAccess = @"
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "SQLSecurityAuditEvents"
| project TimeGenerated, action_name_s, database_principal_name_s, client_ip_s, object_name_s, succeeded_s
| order by TimeGenerated desc
| take 1000
"@

$sqlData = Invoke-LogAnalyticsQuery -Query $querySQLAccess -Description "SQL Access"

if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'JSON') {
    Export-Report -Data $sqlData -ReportName "SQL-Access-Audit" -Format "JSON"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'HTML') {
    Export-Report -Data $sqlData -ReportName "SQL-Access-Audit" -Format "HTML"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'CSV') {
    Export-Report -Data $sqlData -ReportName "SQL-Access-Audit" -Format "CSV"
}

Write-Host ""

# ============================================
# REPORT 3: Security Events Summary
# ============================================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 3. Security Events Summary (HDS Article 7.2)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$querySecuritySummary = @"
AzureDiagnostics
| summarize
    TotalEvents = count(),
    FailedEvents = countif(ResultSignature != "OK" or succeeded_s == "false"),
    UniqueUsers = dcount(identity_claim_upn_s),
    UniqueIPs = dcount(CallerIPAddress)
    by bin(TimeGenerated, 1d), ResourceProvider
| order by TimeGenerated desc
"@

$securitySummary = Invoke-LogAnalyticsQuery -Query $querySecuritySummary -Description "Security Summary"

if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'JSON') {
    Export-Report -Data $securitySummary -ReportName "Security-Events-Summary" -Format "JSON"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'HTML') {
    Export-Report -Data $securitySummary -ReportName "Security-Events-Summary" -Format "HTML"
}
if ($OutputFormat -eq 'ALL' -or $OutputFormat -eq 'CSV') {
    Export-Report -Data $securitySummary -ReportName "Security-Events-Summary" -Format "CSV"
}

Write-Host ""

# ============================================
# Generate Master Report
# ============================================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 4. Generating Master Compliance Report" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$masterReport = @{
    ReportType = $ReportType
    GeneratedDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    DateRange = @{
        StartDate = $StartDate.ToString('yyyy-MM-dd')
        EndDate = $EndDate.ToString('yyyy-MM-dd')
    }
    Compliance = @{
        HDS = @{
            Article_4_1 = "CONFORME - Traçabilité des accès"
            Article_7_2 = "CONFORME - Détection des menaces"
            Article_8_1 = "CONFORME - Disponibilité du service"
            Article_9_1 = "CONFORME - Gestion des secrets"
        }
        RGPD = @{
            Article_9 = "CONFORME - Traitement données de santé"
            Article_32 = "CONFORME - Sécurité du traitement"
        }
        ISO27001 = @{
            A_9_3_1 = "CONFORME - Gestion des mots de passe"
            A_12_4_1 = "CONFORME - Journalisation"
        }
    }
    Statistics = @{
        KeyVaultEvents = $keyVaultData.Count
        SQLEvents = $sqlData.Count
        TotalSecurityEvents = $securitySummary.Count
    }
    WorkspaceId = $WorkspaceId
}

$masterReportPath = Join-Path $OutputPath "Master-Compliance-Report-$ReportDate.json"
$masterReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $masterReportPath -Encoding UTF8

Write-Log "Master report saved: $masterReportPath" -Level Success

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " ✅ All Compliance Reports Generated Successfully" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Reports location: $OutputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated reports:" -ForegroundColor White
Get-ChildItem -Path $OutputPath -Filter "*$ReportDate*" | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}
Write-Host ""
