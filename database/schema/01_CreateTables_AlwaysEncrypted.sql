-- ============================================
-- MedSecure Database Schema with Always Encrypted
-- HDS Article 6.1 - Encryption at Rest and in Transit
-- ============================================

-- Prerequisites:
-- 1. Column Master Key (CMK) must be created in Azure Key Vault
-- 2. Column Encryption Key (CEK) must be created in database
-- 3. Application must use connection string with 'Column Encryption Setting=Enabled'

USE [MedSecureDB]
GO

-- ============================================
-- Column Master Key (CMK)
-- Links to Azure Key Vault key
-- ============================================
-- This is created by PowerShell script Configure-AlwaysEncrypted.ps1
-- Keeping this here for reference:
/*
CREATE COLUMN MASTER KEY [CMK-AlwaysEncrypted]
WITH (
    KEY_STORE_PROVIDER_NAME = 'AZURE_KEY_VAULT',
    KEY_PATH = 'https://kv-medsecure-prod.vault.azure.net/keys/CMK-AlwaysEncrypted'
)
GO
*/

-- ============================================
-- Column Encryption Key (CEK)
-- Encrypted by CMK, used to encrypt data
-- ============================================
-- This is created by PowerShell script Configure-AlwaysEncrypted.ps1
-- Keeping this here for reference:
/*
CREATE COLUMN ENCRYPTION KEY [CEK-AlwaysEncrypted]
WITH VALUES (
    COLUMN_MASTER_KEY = [CMK-AlwaysEncrypted],
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = <binary_value_from_key_vault>
)
GO
*/

-- ============================================
-- Table: Patients
-- Stores patient demographic information
-- ============================================
IF OBJECT_ID('dbo.Patients', 'U') IS NOT NULL
    DROP TABLE dbo.Patients
GO

CREATE TABLE dbo.Patients (
    PatientId INT IDENTITY(1,1) NOT NULL,

    -- Encrypted columns (RGPD Article 9 - Health data protection)
    FirstName NVARCHAR(100) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,  -- Maximum security
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NOT NULL,

    LastName NVARCHAR(100) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NOT NULL,

    -- Deterministic encryption allows equality searches (WHERE SSN = 'xxx')
    SocialSecurityNumber CHAR(15) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Deterministic,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NOT NULL,

    Email NVARCHAR(256) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NULL,

    PhoneNumber NVARCHAR(20) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NULL,

    -- Non-sensitive columns (not encrypted)
    DateOfBirth DATE NOT NULL,
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')) NULL,
    BloodType VARCHAR(3) NULL,

    -- Audit columns
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    ModifiedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_Patients PRIMARY KEY CLUSTERED (PatientId)
)
GO

-- Index on SSN (Deterministic encryption allows indexing)
CREATE UNIQUE NONCLUSTERED INDEX IX_Patients_SSN
ON dbo.Patients(SocialSecurityNumber)
WHERE IsActive = 1
GO

-- ============================================
-- Table: MedicalRecords
-- Stores patient medical history
-- ============================================
IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NOT NULL
    DROP TABLE dbo.MedicalRecords
GO

CREATE TABLE dbo.MedicalRecords (
    RecordId INT IDENTITY(1,1) NOT NULL,
    PatientId INT NOT NULL,

    -- Encrypted columns (HDS Article 6.1)
    Diagnosis NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NULL,

    Treatment NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NULL,

    Notes NVARCHAR(MAX) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [CEK-AlwaysEncrypted],
            ENCRYPTION_TYPE = Randomized,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NULL,

    -- Non-sensitive columns
    RecordDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DoctorId INT NULL,

    -- Audit columns
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    ModifiedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_MedicalRecords PRIMARY KEY CLUSTERED (RecordId),
    CONSTRAINT FK_MedicalRecords_Patients FOREIGN KEY (PatientId)
        REFERENCES dbo.Patients(PatientId)
)
GO

-- Index on PatientId for fast lookups
CREATE NONCLUSTERED INDEX IX_MedicalRecords_PatientId
ON dbo.MedicalRecords(PatientId)
WHERE IsActive = 1
GO

-- ============================================
-- Table: Doctors
-- Stores doctor information (not encrypted)
-- ============================================
IF OBJECT_ID('dbo.Doctors', 'U') IS NOT NULL
    DROP TABLE dbo.Doctors
GO

CREATE TABLE dbo.Doctors (
    DoctorId INT IDENTITY(1,1) NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Specialty NVARCHAR(100) NULL,
    LicenseNumber NVARCHAR(50) NOT NULL,
    Email NVARCHAR(256) NULL,
    PhoneNumber NVARCHAR(20) NULL,

    -- Audit columns
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    ModifiedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedBy NVARCHAR(256) NOT NULL DEFAULT SYSTEM_USER,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_Doctors PRIMARY KEY CLUSTERED (DoctorId)
)
GO

-- ============================================
-- Audit Trigger: Patients
-- Track all modifications (HDS Article 4.1)
-- ============================================
IF OBJECT_ID('dbo.TR_Patients_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_Patients_Audit
GO

CREATE TRIGGER dbo.TR_Patients_Audit
ON dbo.Patients
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Log to audit table (implementation depends on audit table structure)
    -- This is a placeholder - implement based on your audit requirements

    DECLARE @Action VARCHAR(10)

    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Action = 'UPDATE'
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Action = 'INSERT'
    ELSE
        SET @Action = 'DELETE'

    -- Example: INSERT INTO AuditLog (TableName, Action, Timestamp, User)
    -- VALUES ('Patients', @Action, SYSUTCDATETIME(), SYSTEM_USER)
END
GO

-- ============================================
-- Sample Data (for testing - remove in production)
-- ============================================

-- Note: To insert data into encrypted columns, you MUST use a connection
-- with 'Column Encryption Setting=Enabled' and have access to the CMK in Key Vault

-- Example insert (will only work with encrypted connection):
/*
INSERT INTO dbo.Patients (FirstName, LastName, SocialSecurityNumber, DateOfBirth, Gender)
VALUES
    ('Jean', 'Dupont', '1-85-04-75-123-456', '1985-04-15', 'M'),
    ('Marie', 'Martin', '2-90-08-13-234-567', '1990-08-22', 'F'),
    ('Pierre', 'Bernard', '1-78-12-31-345-678', '1978-12-05', 'M')
GO
*/

-- ============================================
-- Views for Data Access
-- ============================================

-- View: Patient Summary (excludes SSN for regular users)
CREATE OR ALTER VIEW dbo.vw_PatientSummary
AS
SELECT
    PatientId,
    FirstName,
    LastName,
    Email,
    PhoneNumber,
    DateOfBirth,
    Gender,
    BloodType,
    CreatedAt,
    ModifiedAt
FROM dbo.Patients
WHERE IsActive = 1
GO

-- View: Medical Records Summary
CREATE OR ALTER VIEW dbo.vw_MedicalRecordsSummary
AS
SELECT
    mr.RecordId,
    mr.PatientId,
    p.FirstName + ' ' + p.LastName AS PatientName,
    mr.Diagnosis,
    mr.Treatment,
    mr.RecordDate,
    d.FirstName + ' ' + d.LastName AS DoctorName
FROM dbo.MedicalRecords mr
INNER JOIN dbo.Patients p ON mr.PatientId = p.PatientId
LEFT JOIN dbo.Doctors d ON mr.DoctorId = d.DoctorId
WHERE mr.IsActive = 1 AND p.IsActive = 1
GO

-- ============================================
-- Permissions (Row-Level Security can be added)
-- ============================================

-- Example: Grant access to application user
-- GRANT SELECT, INSERT, UPDATE ON dbo.Patients TO [appUser]
-- GRANT SELECT, INSERT, UPDATE ON dbo.MedicalRecords TO [appUser]
-- GRANT SELECT ON dbo.Doctors TO [appUser]

PRINT 'Database schema with Always Encrypted created successfully!'
PRINT 'Remember: Applications must use connection string with "Column Encryption Setting=Enabled"'
PRINT 'Compliance: HDS Article 6.1, RGPD Article 32'
GO
