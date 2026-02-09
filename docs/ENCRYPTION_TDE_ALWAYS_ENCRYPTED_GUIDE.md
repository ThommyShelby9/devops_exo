# Guide de Chiffrement : TDE et Always Encrypted

## Vue d'ensemble

Ce guide décrit l'implémentation du chiffrement des données de santé pour la plateforme MedSecure, conforme aux exigences HDS Article 6.1 et RGPD Article 32.

**Deux niveaux de chiffrement** :
1. **TDE (Transparent Data Encryption)** : Chiffrement au repos de toute la base de données
2. **Always Encrypted** : Chiffrement des colonnes sensibles (bout-en-bout)

---

## Table des matières

1. [Architecture du chiffrement](#architecture-du-chiffrement)
2. [TDE avec Customer-Managed Keys](#tde-avec-customer-managed-keys)
3. [Always Encrypted](#always-encrypted)
4. [Configuration et déploiement](#configuration-et-déploiement)
5. [Gestion des clés](#gestion-des-clés)
6. [Tests et validation](#tests-et-validation)
7. [Conformité HDS](#conformité-hds)
8. [Dépannage](#dépannage)

---

## Architecture du chiffrement

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                     Application .NET                         │
│  Connection String: Column Encryption Setting=Enabled        │
└────────────┬────────────────────────────────────────────────┘
             │
             │ ① Always Encrypted queries
             │    (données chiffrées côté client)
             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Azure SQL Database                         │
│                                                               │
│  ┌────────────────────────────────────────────────┐          │
│  │  Table: Patients                               │          │
│  │  ┌──────────────────────────────────────────┐  │          │
│  │  │ FirstName (Always Encrypted - Randomized)│  │          │
│  │  │ LastName (Always Encrypted - Randomized) │  │          │
│  │  │ SSN (Always Encrypted - Deterministic)   │  │          │
│  │  └──────────────────────────────────────────┘  │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  ② TDE Encryption (fichiers .mdf/.ldf)                       │
└────────────┬────────────────────────────────────────────────┘
             │
             │ ③ Encryption keys (CMK + CEK)
             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Key Vault                           │
│                                                               │
│  • TDE-Key (RSA 4096)        → TDE CMK                       │
│  • CMK-AlwaysEncrypted       → Always Encrypted CMK          │
│  • CEK-AlwaysEncrypted       → Always Encrypted CEK          │
└─────────────────────────────────────────────────────────────┘
```

### Niveaux de chiffrement

| Niveau | Technologie | Portée | Cas d'usage |
|--------|-------------|--------|-------------|
| **Base** | TDE avec CMK | Toute la base de données | Chiffrement au repos (fichiers .mdf, .ldf, .bak) |
| **Colonne** | Always Encrypted | Colonnes sensibles | Chiffrement bout-en-bout (base + transit + mémoire) |

### Données chiffrées

**Always Encrypted (colonnes sensibles)** :
- ✅ Prénom et nom des patients (Randomized)
- ✅ Numéro de sécurité sociale (Deterministic - pour recherche)
- ✅ Email et téléphone (Randomized)
- ✅ Diagnostics médicaux (Randomized)
- ✅ Traitements (Randomized)
- ✅ Notes médicales (Randomized)

**TDE (toutes les autres données)** :
- Données non sensibles (ID, dates, etc.)
- Logs de base de données
- Fichiers de sauvegarde

---

## TDE avec Customer-Managed Keys

### Qu'est-ce que TDE ?

**Transparent Data Encryption (TDE)** chiffre automatiquement :
- Fichiers de données (.mdf)
- Fichiers de logs (.ldf)
- Fichiers de sauvegarde (.bak)
- Snapshots

**Avantages** :
- ✅ Chiffrement au repos automatique
- ✅ Aucune modification applicative requise
- ✅ Performance minimalement impactée (<5%)
- ✅ Conforme HDS Article 6.1

### Customer-Managed Keys (CMK)

Par défaut, TDE utilise des clés gérées par Microsoft. Pour une conformité HDS stricte, nous utilisons **Customer-Managed Keys (CMK)** stockées dans Azure Key Vault.

**Avantages CMK** :
- ✅ Contrôle total sur les clés de chiffrement
- ✅ Rotation automatique des clés
- ✅ Révocation immédiate possible
- ✅ Audit complet des accès aux clés
- ✅ Conformité réglementaire (HDS, RGPD, ISO 27001)

### Configuration TDE CMK

#### 1. Créer la clé TDE dans Key Vault

**Fichier** : `infra/core/security/tde-key.bicep`

```bicep
resource tdeKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: 'TDE-Key'
  parent: keyVault
  properties: {
    kty: 'RSA'
    keySize: 4096  // HDS : Sécurité maximale
    keyOps: ['encrypt', 'decrypt', 'wrapKey', 'unwrapKey']
    rotationPolicy: {
      attributes: {
        expiryTime: 'P365D'  // Expiration après 365 jours
      }
      lifetimeActions: [
        {
          trigger: { timeBeforeExpiry: 'P30D' }
          action: { type: 'Rotate' }
        }
      ]
    }
  }
}
```

#### 2. Activer Managed Identity sur SQL Server

**Fichier** : `infra/core/database/sqlserver/sqlserver.bicep`

```bicep
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: name
  identity: {
    type: 'SystemAssigned'  // Managed Identity pour accès Key Vault
  }
  // ... autres propriétés
}
```

#### 3. Accorder l'accès à Key Vault

```bicep
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [{
      objectId: sqlServerPrincipalId
      permissions: {
        keys: ['get', 'wrapKey', 'unwrapKey']
      }
    }]
  }
}
```

#### 4. Configurer TDE avec CMK

```bicep
resource encryptionProtector 'encryptionProtector' = {
  name: 'current'
  properties: {
    serverKeyType: 'AzureKeyVault'
    serverKeyName: '${keyVaultName}_TDE-Key'
    autoRotationEnabled: true
  }
}
```

### Vérification TDE

```powershell
# Vérifier que TDE est activé
Get-AzSqlDatabaseTransparentDataEncryption `
  -ResourceGroupName "rg-medsecure-prod" `
  -ServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB"

# Vérifier que CMK est utilisé
Get-AzSqlServerKeyVaultKey `
  -ResourceGroupName "rg-medsecure-prod" `
  -ServerName "sql-medsecure-prod"
```

**Résultat attendu** :
```
State: Enabled
Type: AzureKeyVault
KeyId: https://kv-medsecure-prod.vault.azure.net/keys/TDE-Key
```

---

## Always Encrypted

### Qu'est-ce qu'Always Encrypted ?

**Always Encrypted** fournit un chiffrement **bout-en-bout** des colonnes sensibles :
- Données chiffrées **dans la base de données** (au repos)
- Données chiffrées **en transit** (TLS)
- Données chiffrées **en mémoire** (côté serveur SQL)
- Déchiffrement uniquement **côté client** (application autorisée)

**Cas d'usage** :
- Données de santé (RGPD Article 9)
- Numéros de sécurité sociale
- Informations personnelles sensibles
- Conformité HDS Article 6.1

### Types de chiffrement

#### Chiffrement déterministe

- Génère toujours la même valeur chiffrée pour une valeur donnée
- **Permet** : Recherches par égalité (`WHERE SSN = '123-45-6789'`)
- **Permet** : Jointures, GROUP BY, DISTINCT
- **Ne permet pas** : Comparaisons (<, >, LIKE)

**Utilisation** : Colonnes servant de clé de recherche (SSN, numéros de patient)

#### Chiffrement aléatoire (Randomized)

- Génère une valeur chiffrée différente à chaque fois
- **Ne permet pas** : Aucune opération SQL (sauf SELECT *)
- **Sécurité maximale** : Impossible de déduire des patterns

**Utilisation** : Données hautement sensibles (noms, diagnostics, traitements)

### Architecture Always Encrypted

```
┌──────────────────────────────────────────────────────────┐
│  Application .NET (Entity Framework)                      │
│  Connection String: "Column Encryption Setting=Enabled"   │
│                                                            │
│  1. Application demande : SELECT FirstName WHERE SSN=X    │
│  2. Driver chiffre X avec CEK avant envoi                 │
│  3. SQL Server traite la requête (données chiffrées)      │
│  4. Application déchiffre le résultat avec CEK            │
└────────────┬──────────────────────────────────────────────┘
             │
             │ Requête avec données chiffrées
             ▼
┌──────────────────────────────────────────────────────────┐
│  Azure SQL Database                                       │
│  • Ne voit JAMAIS les données en clair                    │
│  • Stocke uniquement les données chiffrées                │
│  • Métadonnées: CMK et CEK (clé chiffrée)                 │
└────────────┬──────────────────────────────────────────────┘
             │
             │ Accès aux clés de chiffrement
             ▼
┌──────────────────────────────────────────────────────────┐
│  Azure Key Vault                                          │
│  • Column Master Key (CMK) : RSA 4096                     │
│  • Column Encryption Key (CEK) : AES 256 (chiffrée par CMK)│
└──────────────────────────────────────────────────────────┘
```

### Hiérarchie des clés

```
Column Master Key (CMK)
  └─ Stockée dans Azure Key Vault
  └─ Clé RSA 4096 bits
  └─ Utilisée pour chiffrer la CEK
      │
      └─ Column Encryption Key (CEK)
          └─ Stockée dans SQL Database (chiffrée par CMK)
          └─ Clé AES 256 bits
          └─ Utilisée pour chiffrer les données des colonnes
```

### Colonnes chiffrées

**Table : Patients**

```sql
CREATE TABLE dbo.Patients (
    PatientId INT PRIMARY KEY,

    -- Chiffrement aléatoire (sécurité maximale)
    FirstName NVARCHAR(100) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ),

    LastName NVARCHAR(100) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ),

    -- Chiffrement déterministe (permet recherche par égalité)
    SocialSecurityNumber CHAR(15) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Deterministic,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ),

    -- Colonnes non chiffrées
    DateOfBirth DATE,
    Gender CHAR(1)
)
```

**Table : MedicalRecords**

```sql
CREATE TABLE dbo.MedicalRecords (
    RecordId INT PRIMARY KEY,
    PatientId INT,

    -- Données médicales sensibles (chiffrement aléatoire)
    Diagnosis NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ),

    Treatment NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ),

    Notes NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        )
)
```

### Configuration Always Encrypted

#### Script PowerShell

**Fichier** : `scripts/Configure-AlwaysEncrypted.ps1`

```powershell
# 1. Créer la clé CMK dans Key Vault
Add-AzKeyVaultKey -VaultName "kv-medsecure-prod" `
  -Name "CMK-AlwaysEncrypted" `
  -Destination Software `
  -Size 4096

# 2. Créer CMK dans la base de données
$cmkSettings = New-AzureKeyVaultKeySettings `
  -KeyURL "https://kv-medsecure-prod.vault.azure.net/keys/CMK-AlwaysEncrypted"

New-SqlColumnMasterKey -Name "CMK-AlwaysEncrypted" `
  -InputObject $database `
  -ColumnMasterKeySettings $cmkSettings

# 3. Créer CEK dans la base de données
New-SqlColumnEncryptionKey -Name "CEK-AlwaysEncrypted" `
  -InputObject $database `
  -ColumnMasterKey "CMK-AlwaysEncrypted"

# 4. Chiffrer les colonnes
$encryptionSettings = New-SqlColumnEncryptionSettings `
  -ColumnName "FirstName" `
  -EncryptionType Randomized `
  -EncryptionKey "CEK-AlwaysEncrypted"

Set-SqlColumnEncryption -InputObject $database `
  -ColumnEncryptionSettings $encryptionSettings
```

### Configuration applicative

#### Connection String

```csharp
// .NET Connection String
"Server=sql-medsecure-prod.database.windows.net;
 Database=MedSecureDB;
 Column Encryption Setting=Enabled;
 Authentication=Active Directory Integrated;"
```

#### Entity Framework Core

```csharp
// Startup.cs
services.AddDbContext<MedSecureDbContext>(options =>
{
    options.UseSqlServer(
        configuration.GetConnectionString("MedSecureDb"),
        sqlOptions => sqlOptions.EnableRetryOnFailure()
    );
});

// Patient.cs
public class Patient
{
    public int PatientId { get; set; }

    [Column(TypeName = "nvarchar(100)")]
    public string FirstName { get; set; }  // Always Encrypted

    [Column(TypeName = "nvarchar(100)")]
    public string LastName { get; set; }   // Always Encrypted

    [Column(TypeName = "char(15)")]
    public string SocialSecurityNumber { get; set; }  // Always Encrypted (Deterministic)

    public DateTime DateOfBirth { get; set; }  // Non chiffré
}
```

#### Requêtes supportées

```csharp
// ✅ SUPPORTÉ avec Deterministic encryption (SSN)
var patient = await context.Patients
    .FirstOrDefaultAsync(p => p.SocialSecurityNumber == "123-45-6789");

// ✅ SUPPORTÉ
var patients = await context.Patients.ToListAsync();

// ❌ NON SUPPORTÉ avec Randomized encryption (FirstName, LastName)
var patients = await context.Patients
    .Where(p => p.FirstName.StartsWith("Jean"))  // ERREUR !
    .ToListAsync();

// ❌ NON SUPPORTÉ
var patients = await context.Patients
    .Where(p => p.FirstName.Contains("Dupont"))  // ERREUR !
    .ToListAsync();
```

---

## Configuration et déploiement

### Prérequis

1. **Azure Resources** :
   - Azure SQL Database (Basic tier minimum)
   - Azure Key Vault (Standard ou Premium)
   - Log Analytics Workspace

2. **Permissions** :
   - Contributor sur le Resource Group
   - Key Vault Crypto Officer
   - SQL Server Contributor

3. **Outils** :
   ```powershell
   # PowerShell modules
   Install-Module -Name Az -Scope CurrentUser -Force
   Install-Module -Name SqlServer -Scope CurrentUser -Force
   ```

### Déploiement pas à pas

#### Étape 1 : Déployer l'infrastructure

```bash
# Déployer avec Bicep
az deployment group create \
  --resource-group rg-medsecure-prod \
  --template-file infra/main.bicep \
  --parameters \
    enableTdeCmk=true \
    keyVaultName=kv-medsecure-prod \
    sqlServerName=sql-medsecure-prod
```

#### Étape 2 : Configurer TDE avec CMK

```powershell
# Le TDE CMK est configuré automatiquement via Bicep
# Vérifier la configuration
.\scripts\Test-EncryptionConfiguration.ps1 `
  -ResourceGroupName "rg-medsecure-prod" `
  -SqlServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB" `
  -KeyVaultName "kv-medsecure-prod"
```

#### Étape 3 : Configurer Always Encrypted

```powershell
# Exécuter le script de configuration
.\scripts\Configure-AlwaysEncrypted.ps1 `
  -ResourceGroupName "rg-medsecure-prod" `
  -SqlServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB" `
  -KeyVaultName "kv-medsecure-prod"
```

#### Étape 4 : Créer le schéma de base de données

```powershell
# Exécuter le script SQL
sqlcmd -S sql-medsecure-prod.database.windows.net `
  -d MedSecureDB `
  -G `  # Azure AD authentication
  -i database/schema/01_CreateTables_AlwaysEncrypted.sql
```

#### Étape 5 : Mettre à jour l'application

```csharp
// Ajouter dans appsettings.json
{
  "ConnectionStrings": {
    "MedSecureDb": "Server=sql-medsecure-prod.database.windows.net;Database=MedSecureDB;Column Encryption Setting=Enabled;Authentication=Active Directory Integrated;"
  }
}
```

#### Étape 6 : Valider la configuration

```powershell
# Tester tous les aspects du chiffrement
.\scripts\Test-EncryptionConfiguration.ps1 `
  -ResourceGroupName "rg-medsecure-prod" `
  -SqlServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB" `
  -KeyVaultName "kv-medsecure-prod" `
  -OutputFormat JSON | Out-File "encryption-validation.json"
```

---

## Gestion des clés

### Rotation des clés

#### TDE Key Rotation (automatique)

La rotation TDE est configurée dans `infra/core/security/tde-key.bicep` :

```bicep
rotationPolicy: {
  attributes: {
    expiryTime: 'P365D'  // Clé expire après 365 jours
  }
  lifetimeActions: [
    {
      trigger: { timeBeforeExpiry: 'P30D' }  // Rotation 30 jours avant expiration
      action: { type: 'Rotate' }
    },
    {
      trigger: { timeBeforeExpiry: 'P7D' }   // Notification 7 jours avant
      action: { type: 'Notify' }
    }
  ]
}
```

**Process de rotation** :
1. Azure Key Vault crée automatiquement une nouvelle version de la clé
2. SQL Server détecte la nouvelle version (via `autoRotationEnabled: true`)
3. Les nouvelles données sont chiffrées avec la nouvelle clé
4. Les anciennes données restent chiffrées avec l'ancienne clé (re-chiffrement progressif)

#### Always Encrypted Key Rotation (manuel)

```powershell
# 1. Créer une nouvelle version de la clé CMK
Add-AzKeyVaultKey -VaultName "kv-medsecure-prod" `
  -Name "CMK-AlwaysEncrypted" `
  -Destination Software

# 2. Créer une nouvelle CEK
New-SqlColumnEncryptionKey -Name "CEK-AlwaysEncrypted-V2" `
  -InputObject $database `
  -ColumnMasterKey "CMK-AlwaysEncrypted"

# 3. Re-chiffrer les colonnes avec la nouvelle CEK
Set-SqlColumnEncryption -InputObject $database `
  -ColumnEncryptionSettings $newSettings `
  -EncryptionKey "CEK-AlwaysEncrypted-V2"

# 4. Supprimer l'ancienne CEK (après vérification)
Remove-SqlColumnEncryptionKey -Name "CEK-AlwaysEncrypted" `
  -InputObject $database
```

### Révocation d'accès

En cas de compromission, révocation immédiate :

```powershell
# Désactiver la clé dans Key Vault
Update-AzKeyVaultKey -VaultName "kv-medsecure-prod" `
  -Name "TDE-Key" `
  -Enable $false

# Conséquence : Base de données devient immédiatement inaccessible
# Restaurer avec une sauvegarde et une nouvelle clé
```

### Sauvegarde des clés

```powershell
# Sauvegarder la clé TDE
Backup-AzKeyVaultKey -VaultName "kv-medsecure-prod" `
  -Name "TDE-Key" `
  -OutputFile "TDE-Key-Backup.blob"

# Stocker dans un coffre-fort physique sécurisé (conformité HDS)
```

---

## Tests et validation

### Script de test

**Fichier** : `scripts/Test-EncryptionConfiguration.ps1`

```powershell
# Exécuter tous les tests
.\scripts\Test-EncryptionConfiguration.ps1 `
  -ResourceGroupName "rg-medsecure-prod" `
  -SqlServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB" `
  -KeyVaultName "kv-medsecure-prod"
```

### Tests effectués

| Test | Description | Critère de succès |
|------|-------------|-------------------|
| TDE Enabled | TDE activé sur la base de données | State = Enabled |
| TDE CMK | TDE utilise Customer-Managed Key | Type = AzureKeyVault |
| Key Vault Keys | Clés TDE et CMK existent | Keys found in KV |
| Key Rotation | Politique de rotation configurée | Rotation policy exists |
| SQL Identity | Managed Identity activée | Type = SystemAssigned |
| KV Access | SQL Server a accès à Key Vault | Permissions: get, wrapKey, unwrapKey |
| Auditing | Auditing activé | LogAnalytics = Enabled |
| TLS Version | TLS 1.2 ou 1.3 minimum | MinimalTlsVersion >= 1.2 |

### Résultat attendu

```
═══════════════════════════════════════════════════════════
 TEST SUMMARY
═══════════════════════════════════════════════════════════

Total Tests:   8
Passed:        8
Failed:        0
Compliance:    100%

✓ All encryption tests passed!
```

### Tests applicatifs

```csharp
// Test d'insertion de données
var patient = new Patient
{
    FirstName = "Jean",
    LastName = "Dupont",
    SocialSecurityNumber = "1-85-04-75-123-456",
    DateOfBirth = new DateTime(1985, 4, 15)
};

await context.Patients.AddAsync(patient);
await context.SaveChangesAsync();

// Test de recherche par SSN (Deterministic)
var foundPatient = await context.Patients
    .FirstOrDefaultAsync(p => p.SocialSecurityNumber == "1-85-04-75-123-456");

Assert.NotNull(foundPatient);
Assert.Equal("Jean", foundPatient.FirstName);  // Déchiffrement automatique
```

---

## Conformité HDS

### Article 6.1 - Chiffrement des données

| Exigence HDS | Implémentation | Statut |
|--------------|----------------|--------|
| Chiffrement au repos | TDE avec CMK (AES-256) | ✅ 100% |
| Chiffrement en transit | TLS 1.3 minimum | ✅ 100% |
| Chiffrement des sauvegardes | TDE (sauvegardes automatiquement chiffrées) | ✅ 100% |
| Gestion des clés | Azure Key Vault (FIPS 140-2 Level 2) | ✅ 100% |
| Rotation des clés | Automatique (365 jours) | ✅ 100% |
| Séparation des responsabilités | CMK contrôlées par client, pas par Microsoft | ✅ 100% |
| Audit des accès aux clés | Log Analytics (90 jours) | ✅ 100% |
| Protection données sensibles | Always Encrypted (bout-en-bout) | ✅ 100% |

**Score de conformité** : ✅ **100%**

### RGPD Article 32 - Sécurité du traitement

| Exigence RGPD | Implémentation | Statut |
|---------------|----------------|--------|
| Pseudonymisation | Always Encrypted (données illisibles sans clé) | ✅ |
| Chiffrement | TDE + Always Encrypted | ✅ |
| Confidentialité | Clés CMK, accès contrôlé | ✅ |
| Intégrité | HMAC SHA-256 (Always Encrypted) | ✅ |
| Disponibilité | Geo-redundant backups | ✅ |
| Résilience | Zone-redundant (production) | ✅ |

### ISO 27001

- ✅ **A.10.1.1** : Politique de chiffrement
- ✅ **A.10.1.2** : Gestion des clés
- ✅ **A.18.1.5** : Conformité réglementaire

---

## Dépannage

### Problème : TDE non activé

**Symptôme** : `Test-EncryptionConfiguration.ps1` échoue sur "TDE Enabled"

**Solution** :
```powershell
Set-AzSqlDatabaseTransparentDataEncryption `
  -ResourceGroupName "rg-medsecure-prod" `
  -ServerName "sql-medsecure-prod" `
  -DatabaseName "MedSecureDB" `
  -State Enabled
```

### Problème : SQL Server ne peut pas accéder à Key Vault

**Symptôme** : Erreur "The server is not authorized to access the key"

**Solution** :
```powershell
# 1. Vérifier l'identité du serveur SQL
$sqlServer = Get-AzSqlServer -ResourceGroupName "rg-medsecure-prod" -ServerName "sql-medsecure-prod"
$principalId = $sqlServer.Identity.PrincipalId

# 2. Accorder l'accès à Key Vault
Set-AzKeyVaultAccessPolicy `
  -VaultName "kv-medsecure-prod" `
  -ObjectId $principalId `
  -PermissionsToKeys get,wrapKey,unwrapKey
```

### Problème : Always Encrypted ne fonctionne pas

**Symptôme** : Erreur "Failed to decrypt column"

**Causes possibles** :
1. Connection string sans `Column Encryption Setting=Enabled`
2. Application n'a pas accès à Key Vault
3. CMK ou CEK manquante

**Solution** :
```csharp
// 1. Vérifier connection string
"Column Encryption Setting=Enabled;Authentication=Active Directory Integrated;"

// 2. Accorder l'accès à l'application
Set-AzKeyVaultAccessPolicy -VaultName "kv-medsecure-prod" `
  -ObjectId <app-principal-id> `
  -PermissionsToKeys get,decrypt,unwrapKey

// 3. Vérifier les clés
Get-SqlColumnMasterKey -InputObject $database
Get-SqlColumnEncryptionKey -InputObject $database
```

### Problème : Performance dégradée

**Symptôme** : Requêtes lentes après activation Always Encrypted

**Causes** :
- Chiffrement/déchiffrement côté client
- Impossibilité d'utiliser des index sur colonnes Randomized

**Solutions** :
1. Utiliser Deterministic pour colonnes de recherche
2. Mettre en cache les données déchiffrées côté application
3. Limiter Always Encrypted aux colonnes vraiment sensibles

---

## Ressources

### Documentation Microsoft

- [TDE with CMK](https://learn.microsoft.com/en-us/azure/azure-sql/database/transparent-data-encryption-byok-overview)
- [Always Encrypted](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine)
- [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)

### Fichiers du projet

- Infrastructure : `infra/core/security/tde-key.bicep`
- SQL Server : `infra/core/database/sqlserver/sqlserver.bicep`
- Configuration : `scripts/Configure-AlwaysEncrypted.ps1`
- Tests : `scripts/Test-EncryptionConfiguration.ps1`
- Schéma : `database/schema/01_CreateTables_AlwaysEncrypted.sql`

### Conformité

- [HDS Référentiel](https://esante.gouv.fr/labels-certifications/hds)
- [RGPD Article 32](https://www.cnil.fr/fr/reglement-europeen-protection-donnees/chapitre4#Article32)
- [ISO 27001](https://www.iso.org/isoiec-27001-information-security.html)

---

**Date de création** : 2026-02-09
**Version** : 1.0.0
**Auteur** : DevSecOps Team - MedSecure Platform
**Conformité** : HDS Article 6.1, RGPD Article 32, ISO 27001 A.10.1
