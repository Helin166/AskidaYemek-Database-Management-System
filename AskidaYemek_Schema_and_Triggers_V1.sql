-- =====================================================================================
-- Project: Online Food Delivery & "Suspended Meal" (Askýda Yemek) Database Architecture
-- Description: Core schema, constraints, views, and automated triggers.
-- =====================================================================================

-- 1. TABLES & CONSTRAINTS (DDL)
-- =====================================================================================

CREATE TABLE Musteriler (
    MusteriID INT IDENTITY(1,1) PRIMARY KEY,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    Telefon VARCHAR(15) UNIQUE NOT NULL,
    Eposta VARCHAR(100) UNIQUE,
    Bakiye DECIMAL(18,2) DEFAULT 0,
    IsVerified BIT DEFAULT 0 -- 0: Philanthropist (Hayýrsever), 1: Verified in Need (Ýhtiyaç Sahibi)
);
GO

CREATE TABLE Restoranlar (
    RestoranID INT IDENTITY(1,1) PRIMARY KEY,
    RestoranAdi VARCHAR(100) NOT NULL,
    MutfakTuru VARCHAR(50),
    RestoranPuani DECIMAL(3,2) CHECK (RestoranPuani BETWEEN 1 AND 5),
    Ciro DECIMAL(18,2) DEFAULT 0
);
GO

CREATE TABLE Yemekler (
    YemekID INT IDENTITY(1,1) PRIMARY KEY,
    RestoranID INT NOT NULL,
    YemekAdi VARCHAR(100) NOT NULL,
    Fiyat DECIMAL(18,2) NOT NULL CHECK (Fiyat > 0),
    Kategori VARCHAR(50),
    CONSTRAINT FK_Yemek_Restoran FOREIGN KEY (RestoranID) REFERENCES Restoranlar(RestoranID)
);
GO

CREATE TABLE AskidaYemekHavuzu (
    BagisID INT IDENTITY(1,1) PRIMARY KEY,
    MusteriID INT NULL, -- NULL allows for anonymous donations
    BagisTutari DECIMAL(18,2) NOT NULL CHECK (BagisTutari > 0),
    BagisTarihi DATETIME DEFAULT GETDATE(),
    IsKullanildi BIT DEFAULT 0,
    CONSTRAINT FK_Havuz_Musteri FOREIGN KEY (MusteriID) REFERENCES Musteriler(MusteriID)
);
GO

CREATE TABLE Kuryeler (
    KuryeID INT IDENTITY(1,1) PRIMARY KEY,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    Telefon VARCHAR(15) UNIQUE NOT NULL,
    Plaka VARCHAR(20)
);
GO

CREATE TABLE Siparisler (
    SiparisID INT IDENTITY(1,1) PRIMARY KEY,
    MusteriID INT NOT NULL,
    RestoranID INT NOT NULL,
    KuryeID INT NULL, -- Assigned later in the delivery process
    SiparisTarihi DATETIME DEFAULT GETDATE(),
    ToplamTutar DECIMAL(18,2) DEFAULT 0,
    SiparisDurumu VARCHAR(50) DEFAULT 'Alýndý', 
    IsAskidaYemek BIT DEFAULT 0,
    CONSTRAINT FK_Siparis_Musteri FOREIGN KEY (MusteriID) REFERENCES Musteriler(MusteriID),
    CONSTRAINT FK_Siparis_Restoran FOREIGN KEY (RestoranID) REFERENCES Restoranlar(RestoranID),
    CONSTRAINT FK_Siparis_Kurye FOREIGN KEY (KuryeID) REFERENCES Kuryeler(KuryeID)
);
GO

CREATE TABLE SiparisDetaylari (
    SiparisDetayID INT IDENTITY(1,1) PRIMARY KEY,
    SiparisID INT NOT NULL,
    YemekID INT NOT NULL,
    Adet INT NOT NULL CHECK (Adet > 0),
    BirimFiyat DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Detay_Siparis FOREIGN KEY (SiparisID) REFERENCES Siparisler(SiparisID),
    CONSTRAINT FK_Detay_Yemek FOREIGN KEY (YemekID) REFERENCES Yemekler(YemekID)
);
GO

-- 2. VIEWS (DQL)
-- =====================================================================================

-- View: Monitoring the Suspended Meal (Askýda Yemek) Pool Status
CREATE VIEW vw_AskidaYemekHavuzDurumu AS
SELECT 
    Havuz.BagisID,
    Havuz.BagisTutari,
    Havuz.BagisTarihi,
    CASE WHEN Havuz.IsKullanildi = 0 THEN 'Pending in Pool' ELSE 'Claimed' END AS Durum,
    ISNULL(Musteri.Ad + ' ' + Musteri.Soyad, 'Anonymous Donor') AS BagisciAdi
FROM AskidaYemekHavuzu Havuz
LEFT JOIN Musteriler Musteri ON Havuz.MusteriID = Musteri.MusteriID;
GO

-- 3. TRIGGERS (Automated Business Logic)
-- =====================================================================================

-- Trigger: Updates Restaurant Revenue upon Order Delivery
CREATE TRIGGER trg_CiroEkle
ON Siparisler
AFTER UPDATE
AS
BEGIN
    IF NOT UPDATE(SiparisDurumu) RETURN;

    IF EXISTS (SELECT 1 FROM inserted WHERE SiparisDurumu = 'Teslim Edildi')
    BEGIN
        UPDATE Restoranlar
        SET Ciro = Ciro + i.ToplamTutar
        FROM Restoranlar r
        INNER JOIN inserted i ON r.RestoranID = i.RestoranID
        WHERE i.SiparisDurumu = 'Teslim Edildi';
    END
END;
GO

-- Trigger: Allocates funds from the Suspended Meal Pool for verified users
CREATE TRIGGER trg_HavuzdanKullan
ON Siparisler
AFTER INSERT
AS
BEGIN
    DECLARE @IsAskidaYemek BIT;
    DECLARE @ToplamTutar DECIMAL(18,2);

    SELECT @IsAskidaYemek = IsAskidaYemek, @ToplamTutar = ToplamTutar FROM inserted;

    IF @IsAskidaYemek = 0 RETURN;

    DECLARE @KullanilacakBagisID INT;
    
    SELECT TOP 1 @KullanilacakBagisID = BagisID 
    FROM AskidaYemekHavuzu 
    WHERE IsKullanildi = 0 AND BagisTutari >= @ToplamTutar
    ORDER BY BagisTarihi ASC; 

    IF @KullanilacakBagisID IS NOT NULL
    BEGIN
        UPDATE AskidaYemekHavuzu
        SET IsKullanildi = 1
        WHERE BagisID = @KullanilacakBagisID;
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Error: Insufficient funds in the Suspended Meal Pool.', 16, 1);
    END
END;
GO