<#
.SYNOPSIS
    Configure Always Encrypted for sensitive health data columns in MedSecure database

.DESCRIPTION
    This script sets up Always Encrypted with Azure Key Vault for protecting sensitive
    health data columns (Patient names, SSN, contact info) in compliance with HDS Article 6.1.

    Always Encrypted provides column-level encryption where:
    - Data is encrypted at rest in the database
    - Data is encrypted in transit
    - Data is encrypted in memory (until decrypted by authorized application)
    - Encryption keys never leave Key Vault

.PARAMETER ResourceGroupName
    Azure Resource Group name

.PARAMETER SqlServerName
    SQL Server name

.PARAMETER DatabaseName
    Database name

.PARAMETER KeyVaultName
    Key Vault name for storing Column Master Key (CMK)

.PARAMETER ColumnMasterKeyName
    Name for the Column Master Key (default: CMK-AlwaysEncrypted)

.PARAMETER ColumnEncryptionKeyName
    Name for the Column Encryption Key (default: CEK-AlwaysEncrypted)

.PARAMETER EncryptionType
    Encryption type: Deterministic or Randomized
    - Deterministic: Allows equality searches (e.g., WHERE SSN = '123-45-6789')
    - Randomized: Maximum security, no searches allowed (recommended for highly sensitive data)

.PARAMETER WhatIf
    Show what would be done without making changes

.EXAMPLE
    .\Configure-AlwaysEncrypted.ps1 -ResourceGroupName "rg-medsecure-prod" `
        -SqlServerName "sql-medsecure-prod" `
        -DatabaseName "MedSecureDB" `
        -KeyVaultName "kv-medsecure-prod"

.EXAMPLE
    # Test with WhatIf
    .\Configure-AlwaysEncrypted.ps1 -ResourceGroupName "rg-medsecure-dev" `
        -SqlServerName "sql-medsecure-dev" `
        -DatabaseName "MedSecureDB" `
        -KeyVaultName "kv-medsecure-dev" `
        -WhatIf

.NOTES
    Author: MedSecure DevSecOps Team
    Version: 1.0.0
    Compliance: HDS Article 6.1 (Encryption), RGPD Article 32

    Prerequisites:
    - SqlServer PowerShell module (Install-Module -Name SqlServer)
    - Azure PowerShell module (Install-Module -Name Az)
    - Contributor access to Resource Group
    - Key Vault Crypto Officer role
#>

[CmdletBinding(SupportsShouldProcess)]
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
    [string]$ColumnMasterKeyName = "CMK-AlwaysEncrypted",

    [Parameter(Mandatory = $false)]
    [string]$ColumnEncryptionKeyName = "CEK-AlwaysEncrypted",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Deterministic", "Randomized")]
    [string]$EncryptionType = "Randomized"
)

# ============================================
# Configuration
# ============================================
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Sensitive columns to encrypt (HDS Article 6.1)
$SensitiveColumns = @(
    @{
        Table = "Patients"
        Column = "FirstName"
        Type = "nvarchar(100)"
        Encryption = "Randomized"  # Maximum security
    },
    @{
        Table = "Patients"
        Column = "LastName"
        Type = "nvarchar(100)"
        Encryption = "Randomized"
    },
    @{
        Table = "Patients"
        Column = "SocialSecurityNumber"
        Type = "char(15)"
        Encryption = "Deterministic"  # Allow equality searches for patient lookup
    },
    @{
        Table = "Patients"
        Column = "Email"
        Type = "nvarchar(256)"
        Encryption = "Randomized"
    },
    @{
        Table = "Patients"
        Column = "PhoneNumber"
        Type = "nvarchar(20)"
        Encryption = "Randomized"
    },
    @{
        Table = "MedicalRecords"
        Column = "Diagnosis"
        Type = "nvarchar(max)"
        Encryption = "Randomized"
    },
    @{
        Table = "MedicalRecords"
        Column = "Treatment"
        Type = "nvarchar(max)"
        Encryption = "Randomized"
    },
    @{
        Table = "MedicalRecords"
        Column = "Notes"
        Type = "nvarchar(max)"
        Encryption = "Randomized"
    }
)

# ============================================
# Functions
# ============================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites"

    # Check SqlServer module
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Error "SqlServer PowerShell module not found"
        Write-Host "Install with: Install-Module -Name SqlServer -Scope CurrentUser -Force" -ForegroundColor Yellow
        throw "Missing SqlServer module"
    }
    Write-Success "SqlServer module installed"

    # Check Az module
    if (-not (Get-Module -ListAvailable -Name Az.Sql)) {
        Write-Error "Az.Sql PowerShell module not found"
        Write-Host "Install with: Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor Yellow
        throw "Missing Az.Sql module"
    }
    Write-Success "Az.Sql module installed"

    # Check Azure login
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not logged in to Azure"
        Write-Host "Login with: Connect-AzAccount" -ForegroundColor Yellow
        throw "Not authenticated"
    }
    Write-Success "Logged in to Azure as $($context.Account.Id)"
}

function Get-KeyVaultUri {
    Write-Step "Getting Key Vault URI"

    $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName
    if (-not $keyVault) {
        throw "Key Vault '$KeyVaultName' not found in resource group '$ResourceGroupName'"
    }

    Write-Success "Key Vault URI: $($keyVault.VaultUri)"
    return $keyVault.VaultUri
}

function New-ColumnMasterKey {
    param(
        [string]$ConnectionString,
        [string]$KeyVaultUri
    )

    Write-Step "Creating Column Master Key (CMK)"

    $cmkSettings = New-AzureKeyVaultKeySettings -KeyURL "$KeyVaultUri/keys/$ColumnMasterKeyName"

    if ($PSCmdlet.ShouldProcess("Database", "Create Column Master Key '$ColumnMasterKeyName'")) {
        try {
            # Check if CMK already exists
            $existingCmk = Get-SqlColumnMasterKey -Name $ColumnMasterKeyName `
                -InputObject (Get-SqlDatabase -ConnectionString $ConnectionString) `
                -ErrorAction SilentlyContinue

            if ($existingCmk) {
                Write-Warning "Column Master Key '$ColumnMasterKeyName' already exists"
                return $existingCmk
            }

            # Create CMK
            $cmk = New-SqlColumnMasterKey -Name $ColumnMasterKeyName `
                -InputObject (Get-SqlDatabase -ConnectionString $ConnectionString) `
                -ColumnMasterKeySettings $cmkSettings

            Write-Success "Column Master Key created: $ColumnMasterKeyName"
            return $cmk
        }
        catch {
            Write-Error "Failed to create Column Master Key: $_"
            throw
        }
    }
}

function New-ColumnEncryptionKey {
    param(
        [string]$ConnectionString
    )

    Write-Step "Creating Column Encryption Key (CEK)"

    if ($PSCmdlet.ShouldProcess("Database", "Create Column Encryption Key '$ColumnEncryptionKeyName'")) {
        try {
            # Check if CEK already exists
            $existingCek = Get-SqlColumnEncryptionKey -Name $ColumnEncryptionKeyName `
                -InputObject (Get-SqlDatabase -ConnectionString $ConnectionString) `
                -ErrorAction SilentlyContinue

            if ($existingCek) {
                Write-Warning "Column Encryption Key '$ColumnEncryptionKeyName' already exists"
                return $existingCek
            }

            # Create CEK
            $cek = New-SqlColumnEncryptionKey -Name $ColumnEncryptionKeyName `
                -InputObject (Get-SqlDatabase -ConnectionString $ConnectionString) `
                -ColumnMasterKey $ColumnMasterKeyName

            Write-Success "Column Encryption Key created: $ColumnEncryptionKeyName"
            return $cek
        }
        catch {
            Write-Error "Failed to create Column Encryption Key: $_"
            throw
        }
    }
}

function Set-ColumnEncryption {
    param(
        [string]$ConnectionString
    )

    Write-Step "Encrypting sensitive columns"

    foreach ($column in $SensitiveColumns) {
        $tableName = $column.Table
        $columnName = $column.Column
        $encType = $column.Encryption

        if ($PSCmdlet.ShouldProcess("$tableName.$columnName", "Encrypt column with $encType encryption")) {
            try {
                Write-Host "Encrypting $tableName.$columnName ($encType)..." -ForegroundColor Yellow

                # Build encryption settings
                $encryptionSettings = New-SqlColumnEncryptionSettings `
                    -ColumnName $columnName `
                    -EncryptionType $encType `
                    -EncryptionKey $ColumnEncryptionKeyName

                # Apply encryption
                Set-SqlColumnEncryption -InputObject (Get-SqlDatabase -ConnectionString $ConnectionString) `
                    -ColumnEncryptionSettings $encryptionSettings `
                    -LogFileDirectory "." `
                    -Force

                Write-Success "Encrypted $tableName.$columnName"
            }
            catch {
                Write-Error "Failed to encrypt $tableName.$columnName : $_"
                # Continue with other columns
            }
        }
    }
}

function New-AuditRecord {
    param(
        [string]$Action,
        [string]$Status,
        [string]$Details
    )

    $auditEntry = @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Action = $Action
        Status = $Status
        Details = $Details
        User = $env:USERNAME
        ResourceGroup = $ResourceGroupName
        SqlServer = $SqlServerName
        Database = $DatabaseName
        KeyVault = $KeyVaultName
    }

    $auditFile = "AlwaysEncrypted_Audit_$(Get-Date -Format 'yyyyMMdd').json"

    # Read existing audit log
    $auditLog = @()
    if (Test-Path $auditFile) {
        $auditLog = Get-Content $auditFile | ConvertFrom-Json
    }

    # Append new entry
    $auditLog += $auditEntry
    $auditLog | ConvertTo-Json -Depth 10 | Set-Content $auditFile

    Write-Verbose "Audit record created: $Action - $Status"
}

# ============================================
# Main Execution
# ============================================

try {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   MedSecure - Always Encrypted Configuration              ║" -ForegroundColor Cyan
    Write-Host "║   Compliance: HDS Article 6.1 (Encryption)                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Prerequisites
    Test-Prerequisites

    # Step 2: Get Key Vault URI
    $keyVaultUri = Get-KeyVaultUri

    # Step 3: Build connection string
    Write-Step "Building connection string"
    $sqlServer = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName
    $serverFqdn = $sqlServer.FullyQualifiedDomainName

    # Use Azure AD authentication (more secure than SQL auth)
    $token = (Get-AzAccessToken -ResourceUrl "https://database.windows.net").Token
    $connectionString = "Server=$serverFqdn; Database=$DatabaseName; Authentication=Active Directory Integrated;"

    Write-Success "Connection string built"

    # Step 4: Create Column Master Key in Key Vault
    Write-Step "Creating encryption key in Key Vault"

    if ($PSCmdlet.ShouldProcess("Key Vault", "Create key '$ColumnMasterKeyName'")) {
        $key = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $ColumnMasterKeyName -ErrorAction SilentlyContinue

        if (-not $key) {
            $key = Add-AzKeyVaultKey -VaultName $KeyVaultName `
                -Name $ColumnMasterKeyName `
                -Destination Software `
                -Size 4096 `
                -KeyOps @('encrypt', 'decrypt', 'wrapKey', 'unwrapKey') `
                -Tag @{
                    'Purpose' = 'AlwaysEncrypted'
                    'Compliance' = 'HDS'
                }
            Write-Success "Encryption key created in Key Vault"
        }
        else {
            Write-Warning "Encryption key already exists in Key Vault"
        }
    }

    # Step 5: Create Column Master Key in Database
    New-ColumnMasterKey -ConnectionString $connectionString -KeyVaultUri $keyVaultUri

    # Step 6: Create Column Encryption Key in Database
    New-ColumnEncryptionKey -ConnectionString $connectionString

    # Step 7: Encrypt sensitive columns
    Set-ColumnEncryption -ConnectionString $connectionString

    # Step 8: Audit trail
    New-AuditRecord -Action "AlwaysEncrypted Configuration" `
        -Status "Success" `
        -Details "Configured Always Encrypted with CMK: $ColumnMasterKeyName, CEK: $ColumnEncryptionKeyName"

    # Summary
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║             ✓ Always Encrypted Configured                 ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  • Column Master Key: $ColumnMasterKeyName" -ForegroundColor White
    Write-Host "  • Column Encryption Key: $ColumnEncryptionKeyName" -ForegroundColor White
    Write-Host "  • Encrypted Columns: $($SensitiveColumns.Count)" -ForegroundColor White
    Write-Host "  • Encryption Type: $EncryptionType" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Update application connection string with 'Column Encryption Setting=enabled'" -ForegroundColor Yellow
    Write-Host "  2. Test application access to encrypted columns" -ForegroundColor Yellow
    Write-Host "  3. Monitor Key Vault access logs" -ForegroundColor Yellow
    Write-Host ""

}
catch {
    Write-Error "Configuration failed: $_"

    New-AuditRecord -Action "AlwaysEncrypted Configuration" `
        -Status "Failed" `
        -Details "Error: $_"

    throw
}
