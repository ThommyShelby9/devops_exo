<#
.SYNOPSIS
    Test and validate TDE and Always Encrypted configuration for MedSecure database

.DESCRIPTION
    This script validates that:
    1. TDE is enabled with Customer-Managed Keys (CMK)
    2. Always Encrypted is configured correctly
    3. Encryption keys are properly rotated
    4. Access controls are in place
    5. Audit logging is enabled

.PARAMETER ResourceGroupName
    Azure Resource Group name

.PARAMETER SqlServerName
    SQL Server name

.PARAMETER DatabaseName
    Database name

.PARAMETER KeyVaultName
    Key Vault name

.PARAMETER OutputFormat
    Output format: Table, List, or JSON (default: Table)

.EXAMPLE
    .\Test-EncryptionConfiguration.ps1 -ResourceGroupName "rg-medsecure-prod" `
        -SqlServerName "sql-medsecure-prod" `
        -DatabaseName "MedSecureDB" `
        -KeyVaultName "kv-medsecure-prod"

.EXAMPLE
    # Export results as JSON
    .\Test-EncryptionConfiguration.ps1 -ResourceGroupName "rg-medsecure-prod" `
        -SqlServerName "sql-medsecure-prod" `
        -DatabaseName "MedSecureDB" `
        -KeyVaultName "kv-medsecure-prod" `
        -OutputFormat JSON | Out-File "encryption-test-results.json"

.NOTES
    Author: MedSecure DevSecOps Team
    Version: 1.0.0
    Compliance: HDS Article 6.1 (Encryption)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Table", "List", "JSON")]
    [string]$OutputFormat = "Table"
)

# ============================================
# Configuration
# ============================================
$ErrorActionPreference = "Continue"
$testResults = @()

# ============================================
# Functions
# ============================================

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Recommendation = ""
    )

    $status = if ($Passed) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host "`n$status - $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "  Details: $Details" -ForegroundColor Gray
    }
    if ($Recommendation -and -not $Passed) {
        Write-Host "  Recommendation: $Recommendation" -ForegroundColor Yellow
    }

    # Store result
    $script:testResults += [PSCustomObject]@{
        TestName = $TestName
        Status = if ($Passed) { "Pass" } else { "Fail" }
        Details = $Details
        Recommendation = $Recommendation
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Test-TdeEnabled {
    Write-TestHeader "TEST 1: TDE (Transparent Data Encryption) Enabled"

    try {
        $database = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName `
            -ServerName $SqlServerName `
            -DatabaseName $DatabaseName

        $tdeConfig = Get-AzSqlDatabaseTransparentDataEncryption `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $SqlServerName `
            -DatabaseName $DatabaseName

        $isEnabled = $tdeConfig.State -eq "Enabled"

        Write-TestResult -TestName "TDE Enabled" `
            -Passed $isEnabled `
            -Details "TDE State: $($tdeConfig.State)" `
            -Recommendation "Enable TDE in Azure Portal or via PowerShell: Set-AzSqlDatabaseTransparentDataEncryption"

        return $isEnabled
    }
    catch {
        Write-TestResult -TestName "TDE Enabled" `
            -Passed $false `
            -Details "Error: $_" `
            -Recommendation "Check database exists and you have permissions"
        return $false
    }
}

function Test-TdeCmk {
    Write-TestHeader "TEST 2: TDE with Customer-Managed Keys (CMK)"

    try {
        $encryptionProtector = Get-AzSqlServerKeyVaultKey -ResourceGroupName $ResourceGroupName `
            -ServerName $SqlServerName

        if ($encryptionProtector) {
            $isCmk = $encryptionProtector.Type -eq "AzureKeyVault"
            $keyName = $encryptionProtector.KeyId

            Write-TestResult -TestName "TDE using CMK" `
                -Passed $isCmk `
                -Details "Encryption Type: $($encryptionProtector.Type), Key: $keyName" `
                -Recommendation "Configure CMK: Add-AzSqlServerKeyVaultKey and Set-AzSqlServerTransparentDataEncryptionProtector"

            return $isCmk
        }
        else {
            Write-TestResult -TestName "TDE using CMK" `
                -Passed $false `
                -Details "No Key Vault key configured (using service-managed key)" `
                -Recommendation "Configure CMK for enhanced security and compliance"
            return $false
        }
    }
    catch {
        Write-TestResult -TestName "TDE using CMK" `
            -Passed $false `
            -Details "Error checking CMK: $_" `
            -Recommendation "Verify Key Vault integration"
        return $false
    }
}

function Test-KeyVaultKey {
    Write-TestHeader "TEST 3: Key Vault Encryption Keys"

    try {
        # Check TDE key
        $tdeKey = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name "TDE-Key" -ErrorAction SilentlyContinue
        $tdeKeyExists = $null -ne $tdeKey

        Write-TestResult -TestName "TDE Key in Key Vault" `
            -Passed $tdeKeyExists `
            -Details $(if ($tdeKey) { "Key: $($tdeKey.Name), Created: $($tdeKey.Created)" } else { "TDE-Key not found" }) `
            -Recommendation "Create TDE key: Add-AzKeyVaultKey -VaultName '$KeyVaultName' -Name 'TDE-Key'"

        # Check Always Encrypted CMK
        $cmkKey = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name "CMK-AlwaysEncrypted" -ErrorAction SilentlyContinue
        $cmkKeyExists = $null -ne $cmkKey

        Write-TestResult -TestName "Always Encrypted CMK in Key Vault" `
            -Passed $cmkKeyExists `
            -Details $(if ($cmkKey) { "Key: $($cmkKey.Name), Created: $($cmkKey.Created)" } else { "CMK-AlwaysEncrypted not found" }) `
            -Recommendation "Run Configure-AlwaysEncrypted.ps1 script"

        return ($tdeKeyExists -and $cmkKeyExists)
    }
    catch {
        Write-TestResult -TestName "Key Vault Keys" `
            -Passed $false `
            -Details "Error: $_" `
            -Recommendation "Check Key Vault access permissions"
        return $false
    }
}

function Test-KeyRotation {
    Write-TestHeader "TEST 4: Key Rotation Policy"

    try {
        $tdeKey = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name "TDE-Key" -ErrorAction SilentlyContinue

        if ($tdeKey) {
            # Check key age
            $keyAge = (Get-Date) - $tdeKey.Created
            $isRecent = $keyAge.TotalDays -le 365

            Write-TestResult -TestName "TDE Key Age" `
                -Passed $isRecent `
                -Details "Key created $($keyAge.TotalDays.ToString('F0')) days ago" `
                -Recommendation "Rotate keys annually (HDS Article 9.1)"

            # Check if key has rotation policy
            $rotationPolicy = Get-AzKeyVaultKeyRotationPolicy -VaultName $KeyVaultName -Name "TDE-Key" -ErrorAction SilentlyContinue
            $hasRotation = $null -ne $rotationPolicy

            Write-TestResult -TestName "TDE Key Rotation Policy" `
                -Passed $hasRotation `
                -Details $(if ($hasRotation) { "Rotation policy configured" } else { "No rotation policy" }) `
                -Recommendation "Configure automatic key rotation"

            return $isRecent
        }
        else {
            Write-TestResult -TestName "TDE Key Rotation" `
                -Passed $false `
                -Details "TDE key not found" `
                -Recommendation "Create TDE key first"
            return $false
        }
    }
    catch {
        Write-TestResult -TestName "Key Rotation" `
            -Passed $false `
            -Details "Error: $_"
        return $false
    }
}

function Test-SqlServerIdentity {
    Write-TestHeader "TEST 5: SQL Server Managed Identity"

    try {
        $sqlServer = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName

        $hasIdentity = $sqlServer.Identity.Type -eq "SystemAssigned"

        Write-TestResult -TestName "SQL Server Managed Identity" `
            -Passed $hasIdentity `
            -Details "Identity Type: $($sqlServer.Identity.Type)" `
            -Recommendation "Enable System-Assigned Managed Identity for Key Vault access"

        return $hasIdentity
    }
    catch {
        Write-TestResult -TestName "SQL Server Managed Identity" `
            -Passed $false `
            -Details "Error: $_"
        return $false
    }
}

function Test-KeyVaultAccessPolicy {
    Write-TestHeader "TEST 6: Key Vault Access Policy"

    try {
        $sqlServer = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName
        $sqlServerPrincipalId = $sqlServer.Identity.PrincipalId

        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName
        $accessPolicies = $keyVault.AccessPolicies

        $sqlServerPolicy = $accessPolicies | Where-Object { $_.ObjectId -eq $sqlServerPrincipalId }

        $hasAccess = $null -ne $sqlServerPolicy
        $hasCorrectPermissions = $false

        if ($sqlServerPolicy) {
            $keyPermissions = $sqlServerPolicy.PermissionsToKeys
            $hasCorrectPermissions = ($keyPermissions -contains "Get") -and
                                      ($keyPermissions -contains "WrapKey") -and
                                      ($keyPermissions -contains "UnwrapKey")
        }

        Write-TestResult -TestName "SQL Server Access to Key Vault" `
            -Passed ($hasAccess -and $hasCorrectPermissions) `
            -Details $(if ($hasAccess) { "Permissions: $($keyPermissions -join ', ')" } else { "No access policy found" }) `
            -Recommendation "Grant SQL Server access: Set-AzKeyVaultAccessPolicy -VaultName '$KeyVaultName' -ObjectId '$sqlServerPrincipalId' -PermissionsToKeys get,wrapKey,unwrapKey"

        return ($hasAccess -and $hasCorrectPermissions)
    }
    catch {
        Write-TestResult -TestName "Key Vault Access Policy" `
            -Passed $false `
            -Details "Error: $_"
        return $false
    }
}

function Test-AuditingEnabled {
    Write-TestHeader "TEST 7: Database Auditing"

    try {
        $auditPolicy = Get-AzSqlDatabaseAudit -ResourceGroupName $ResourceGroupName `
            -ServerName $SqlServerName `
            -DatabaseName $DatabaseName

        $isEnabled = $auditPolicy.BlobStorageTargetState -eq "Enabled" -or
                     $auditPolicy.LogAnalyticsTargetState -eq "Enabled"

        Write-TestResult -TestName "Database Auditing Enabled" `
            -Passed $isEnabled `
            -Details "Blob Storage: $($auditPolicy.BlobStorageTargetState), Log Analytics: $($auditPolicy.LogAnalyticsTargetState)" `
            -Recommendation "Enable auditing to Log Analytics for HDS compliance"

        return $isEnabled
    }
    catch {
        Write-TestResult -TestName "Database Auditing" `
            -Passed $false `
            -Details "Error: $_"
        return $false
    }
}

function Test-TlsVersion {
    Write-TestHeader "TEST 8: TLS Version"

    try {
        $sqlServer = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName

        $tlsVersion = $sqlServer.MinimalTlsVersion
        $isSecure = $tlsVersion -eq "1.3" -or $tlsVersion -eq "1.2"

        Write-TestResult -TestName "Minimum TLS Version" `
            -Passed $isSecure `
            -Details "TLS Version: $tlsVersion" `
            -Recommendation "Set minimum TLS to 1.3 for HDS compliance"

        return $isSecure
    }
    catch {
        Write-TestResult -TestName "TLS Version" `
            -Passed $false `
            -Details "Error: $_"
        return $false
    }
}

function Get-ComplianceScore {
    $totalTests = $testResults.Count
    $passedTests = ($testResults | Where-Object { $_.Status -eq "Pass" }).Count
    $score = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }

    return @{
        TotalTests = $totalTests
        PassedTests = $passedTests
        FailedTests = $totalTests - $passedTests
        Score = $score
    }
}

# ============================================
# Main Execution
# ============================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   MedSecure - Encryption Configuration Tests              ║" -ForegroundColor Cyan
Write-Host "║   Compliance: HDS Article 6.1 (Encryption)                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing encryption configuration for:" -ForegroundColor White
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "  SQL Server: $SqlServerName" -ForegroundColor Gray
Write-Host "  Database: $DatabaseName" -ForegroundColor Gray
Write-Host "  Key Vault: $KeyVaultName" -ForegroundColor Gray

# Run all tests
Test-TdeEnabled
Test-TdeCmk
Test-KeyVaultKey
Test-KeyRotation
Test-SqlServerIdentity
Test-KeyVaultAccessPolicy
Test-AuditingEnabled
Test-TlsVersion

# Generate summary
$compliance = Get-ComplianceScore

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " TEST SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:   $($compliance.TotalTests)" -ForegroundColor White
Write-Host "Passed:        $($compliance.PassedTests)" -ForegroundColor Green
Write-Host "Failed:        $($compliance.FailedTests)" -ForegroundColor Red
Write-Host "Compliance:    $($compliance.Score)%" -ForegroundColor $(if ($compliance.Score -eq 100) { "Green" } elseif ($compliance.Score -ge 80) { "Yellow" } else { "Red" })
Write-Host ""

# Output results in specified format
switch ($OutputFormat) {
    "Table" {
        $testResults | Format-Table -AutoSize
    }
    "List" {
        $testResults | Format-List
    }
    "JSON" {
        $output = @{
            Summary = $compliance
            Tests = $testResults
            Metadata = @{
                ResourceGroup = $ResourceGroupName
                SqlServer = $SqlServerName
                Database = $DatabaseName
                KeyVault = $KeyVaultName
                TestDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        $output | ConvertTo-Json -Depth 10
    }
}

# Exit code based on compliance
if ($compliance.Score -eq 100) {
    Write-Host "✓ All encryption tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "⚠ Some encryption tests failed. Review recommendations above." -ForegroundColor Yellow
    exit 1
}
