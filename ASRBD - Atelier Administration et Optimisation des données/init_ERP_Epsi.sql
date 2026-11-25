-- ============================================================================
-- Script d'initialisation et de peuplement de la base ERP_Epsi
-- Compatible SQL Server 2022 / 2025 (utilise GENERATE_SERIES)
-- Exécution : sqlcmd -S localhost -U sa -P 'VotreMotDePasse' -C -i init_ERP_Epsi.sql
-- ============================================================================

USE ERP_Epsi;
GO

IF SCHEMA_ID(N'metier') IS NULL
    EXEC(N'CREATE SCHEMA metier');
GO

-- 1. Table Clients
IF OBJECT_ID(N'metier.Clients', N'U') IS NULL
BEGIN
    CREATE TABLE metier.Clients (
        IdClient     INT IDENTITY(1,1) PRIMARY KEY,
        Nom          NVARCHAR(100) NOT NULL,
        Email        NVARCHAR(150) UNIQUE NOT NULL,
        Ville        NVARCHAR(80)  NOT NULL,
        DateCreation DATETIME2     DEFAULT SYSDATETIME()
    );
END
GO

-- 2. Table Produits
IF OBJECT_ID(N'metier.Produits', N'U') IS NULL
BEGIN
    CREATE TABLE metier.Produits (
        IdProduit INT IDENTITY(1,1) PRIMARY KEY,
        Reference NVARCHAR(30)  UNIQUE NOT NULL,
        Libelle   NVARCHAR(120) NOT NULL,
        Categorie NVARCHAR(60)  NOT NULL,
        PrixHT    DECIMAL(10,2) NOT NULL,
        Stock     INT           NOT NULL
    );
END
GO

-- 3. Table Commandes
IF OBJECT_ID(N'metier.Commandes', N'U') IS NULL
BEGIN
    CREATE TABLE metier.Commandes (
        IdCommande   INT IDENTITY(1,1) PRIMARY KEY,
        IdClient     INT           NOT NULL FOREIGN KEY REFERENCES metier.Clients(IdClient),
        DateCommande DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
        Statut       NVARCHAR(20)  NOT NULL,
        MontantHT    DECIMAL(12,2) NOT NULL
    );
END
GO

-- 4. Table LignesCommande
IF OBJECT_ID(N'metier.LignesCommande', N'U') IS NULL
BEGIN
    CREATE TABLE metier.LignesCommande (
        IdLigne      INT IDENTITY(1,1) PRIMARY KEY,
        IdCommande   INT           NOT NULL FOREIGN KEY REFERENCES metier.Commandes(IdCommande),
        IdProduit    INT           NOT NULL FOREIGN KEY REFERENCES metier.Produits(IdProduit),
        Quantite     INT           NOT NULL,
        PrixUnitaire DECIMAL(10,2) NOT NULL
    );
END
GO

-- ============================================================================
-- Peuplement (exécuté uniquement si les tables sont vides)
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM metier.Clients)
BEGIN
    INSERT INTO metier.Clients (Nom, Email, Ville, DateCreation)
    SELECT
        N'Client_' + CAST(v.value AS NVARCHAR(10)),
        N'client' + CAST(v.value AS NVARCHAR(10)) + N'@epsishop.fr',
        CASE v.value % 5
            WHEN 0 THEN N'Paris'
            WHEN 1 THEN N'Lyon'
            WHEN 2 THEN N'Nantes'
            WHEN 3 THEN N'Bordeaux'
            ELSE N'Lille'
        END,
        DATEADD(DAY, -(v.value % 365), SYSDATETIME())
    FROM GENERATE_SERIES(1, 500) AS v;
END
GO

IF NOT EXISTS (SELECT 1 FROM metier.Produits)
BEGIN
    INSERT INTO metier.Produits (Reference, Libelle, Categorie, PrixHT, Stock)
    SELECT
        N'REF-' + RIGHT('0000' + CAST(v.value AS NVARCHAR(10)), 4),
        N'Produit Catalogue ' + CAST(v.value AS NVARCHAR(10)),
        CASE v.value % 4
            WHEN 0 THEN N'Informatique'
            WHEN 1 THEN N'Réseau'
            WHEN 2 THEN N'Stockage'
            ELSE N'Accessoires'
        END,
        CAST(15.00 + (v.value * 3.75) % 450 AS DECIMAL(10,2)),
        10 + (v.value * 7) % 200
    FROM GENERATE_SERIES(1, 100) AS v;
END
GO

IF NOT EXISTS (SELECT 1 FROM metier.Commandes)
BEGIN
    INSERT INTO metier.Commandes (IdClient, DateCommande, Statut, MontantHT)
    SELECT
        1 + (v.value % 500),
        DATEADD(MINUTE, -(v.value * 17), SYSDATETIME()),
        CASE v.value % 4
            WHEN 0 THEN N'Payée'
            WHEN 1 THEN N'Expédiée'
            WHEN 2 THEN N'Livrée'
            ELSE N'En attente'
        END,
        CAST(50.00 + (v.value * 19.50) % 1500 AS DECIMAL(12,2))
    FROM GENERATE_SERIES(1, 2000) AS v;
END
GO

IF NOT EXISTS (SELECT 1 FROM metier.LignesCommande)
BEGIN
    INSERT INTO metier.LignesCommande (IdCommande, IdProduit, Quantite, PrixUnitaire)
    SELECT
        1 + (v.value % 2000),
        1 + ((v.value * 3) % 100),
        1 + (v.value % 5),
        CAST(15.00 + (v.value * 4.25) % 300 AS DECIMAL(10,2))
    FROM GENERATE_SERIES(1, 5000) AS v;
END
GO

-- Vérification des volumes insérés
SELECT 'Clients' AS TableNom, COUNT(*) AS NbLignes FROM metier.Clients
UNION ALL
SELECT 'Produits', COUNT(*) FROM metier.Produits
UNION ALL
SELECT 'Commandes', COUNT(*) FROM metier.Commandes
UNION ALL
SELECT 'LignesCommande', COUNT(*) FROM metier.LignesCommande;
GO
