-- PHASE 2: SECURITY, FULL MOCK DATA & ANALYTICAL QUERIES
USE AskidaYemekDB;
GO

-- 1. SOFT DELETE (IsActive) COLUMNS
ALTER TABLE Musteriler ADD IsActive BIT DEFAULT 1;
ALTER TABLE Restoranlar ADD IsActive BIT DEFAULT 1;
ALTER TABLE Yemekler ADD IsActive BIT DEFAULT 1;
ALTER TABLE Kuryeler ADD IsActive BIT DEFAULT 1;
GO

-- 2. MOCK DATA GENERATION
SET NOCOUNT ON;

-- Seed Data: 20 Customers 
INSERT INTO Musteriler (Ad, Soyad, Telefon, Eposta, Bakiye, IsVerified) VALUES
('Ali', 'Yilmaz', '5551110001', 'ali@mail.com', 1000, 0), ('Ayse', 'Kaya', '5551110002', 'ayse@mail.com', 500, 0),
('Mehmet', 'Demir', '5551110003', 'mehmet@mail.com', 750, 0), ('Fatma', 'Celik', '5551110004', 'fatma@mail.com', 0, 1),
('Can', 'Ozkan', '5551110005', 'can@mail.com', 1200, 0), ('Elif', 'Sahin', '5551110006', 'elif@mail.com', 0, 1),
('Burak', 'Aydin', '5551110007', 'burak@mail.com', 600, 0), ('Zeynep', 'Koc', '5551110008', 'zeynep@mail.com', 0, 1),
('Emre', 'Arslan', '5551110009', 'emre@mail.com', 900, 0), ('Ceren', 'Dogan', '5551110010', 'ceren@mail.com', 0, 1),
('Tarik', 'Turan', '5551110011', 'tarik@mail.com', 400, 0), ('Gizem', 'Bulut', '5551110012', 'gizem@mail.com', 0, 1),
('Oguz', 'Gul', '5551110013', 'oguz@mail.com', 850, 0), ('Merve', 'Tas', '5551110014', 'merve@mail.com', 0, 1),
('Sinan', 'Ak', '5551110015', 'sinan@mail.com', 300, 0), ('Eda', 'Er', '5551110016', 'eda@mail.com', 0, 1),
('Onur', 'Gunes', '5551110017', 'onur@mail.com', 1100, 0),('Selin', 'Yildiz', '5551110018', 'selin@mail.com', 0, 1),
('Kaan', 'Ozturk', '5551110019', 'kaan@mail.com', 700, 0), ('Busra', 'Tekin', '5551110020', 'busra@mail.com', 0, 1);

-- Seed Data: 5 Restaurants
INSERT INTO Restoranlar (RestoranAdi, MutfakTuru, RestoranPuani) VALUES
('Burger Dunyasi', 'Fast Food', 4.5), ('Pizza Evi', 'Italian', 4.8), 
('Kebap Diyari', 'Turkish', 4.7), ('Sushi Ruzgari', 'Asian', 4.2), 
('Tatli Krizim', 'Dessert', 4.9);

-- Seed Data: 5 Couriers
INSERT INTO Kuryeler (Ad, Soyad, Telefon, Plaka) VALUES
('Hasan', 'Sen', '5001112233', '35 ABC 123'), ('Kemal', 'Dag', '5001112234', '35 DEF 456'),
('Murat', 'Deniz', '5001112235', '35 GHI 789'), ('Cemal', 'Ova', '5001112236', '35 JKL 012'),
('Orhan', 'Tepe', '5001112237', '35 MNO 345');

-- Seed Data: 50 Menu Items (Automated)
DECLARE @i INT = 1;
DECLARE @RestoranID INT = 1;
WHILE @i <= 50
BEGIN
    INSERT INTO Yemekler (RestoranID, YemekAdi, Fiyat, Kategori)
    VALUES (@RestoranID, 'Special Menu ' + CAST(@i AS VARCHAR), (RAND() * 100) + 50, 'Main Course');
    IF @i % 10 = 0 SET @RestoranID = @RestoranID + 1;
    SET @i = @i + 1;
END;

-- Seed Data: Initial Suspended Meal Donations
INSERT INTO AskidaYemekHavuzu (MusteriID, BagisTutari) VALUES
(1, 1000), (2, 500), (3, 750), (5, 1200), (7, 600);

-- Seed Data: 100 Random Orders
DECLARE @SiparisSayaci INT = 1;
DECLARE @YeniSiparisID INT;
DECLARE @SecilenRestoran INT;
DECLARE @SecilenYemek INT;
DECLARE @YemekFiyati DECIMAL(18,2);

WHILE @SiparisSayaci <= 100
BEGIN
    SET @SecilenRestoran = (ABS(CHECKSUM(NEWID())) % 5) + 1;
    
    INSERT INTO Siparisler (MusteriID, RestoranID, KuryeID, SiparisTarihi, SiparisDurumu, IsAskidaYemek)
    VALUES (
        (ABS(CHECKSUM(NEWID())) % 20) + 1, @SecilenRestoran, (ABS(CHECKSUM(NEWID())) % 5) + 1, 
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 30), GETDATE()), 
        CASE WHEN @SiparisSayaci % 3 = 0 THEN 'Alindi' ELSE 'Teslim Edildi' END, 0 
    );
    
    SET @YeniSiparisID = SCOPE_IDENTITY();
    SELECT TOP 1 @SecilenYemek = YemekID, @YemekFiyati = Fiyat FROM Yemekler WHERE RestoranID = @SecilenRestoran ORDER BY NEWID();
    
    INSERT INTO SiparisDetaylari (SiparisID, YemekID, Adet, BirimFiyat)
    VALUES (@YeniSiparisID, @SecilenYemek, (ABS(CHECKSUM(NEWID())) % 3) + 1, @YemekFiyati);
    
    UPDATE Siparisler SET ToplamTutar = (SELECT SUM(Adet * BirimFiyat) FROM SiparisDetaylari WHERE SiparisID = @YeniSiparisID)
    WHERE SiparisID = @YeniSiparisID;
    SET @SiparisSayaci = @SiparisSayaci + 1;
END;
GO

-- 3. PROGRAMMABILITY (VIEWS & INDEXES)
GO
CREATE VIEW vw_AskidaYemekHavuzDurumu AS
SELECT m.Ad, m.Soyad, a.BagisTutari, a.BagisTarihi, a.IsKullanildi
FROM AskidaYemekHavuzu a
INNER JOIN Musteriler m ON a.MusteriID = m.MusteriID;
GO

CREATE VIEW vw_AktifRestoranMenuleri AS
SELECT r.RestoranAdi, y.YemekAdi, y.Fiyat, y.Kategori
FROM Restoranlar r
INNER JOIN Yemekler y ON r.RestoranID = y.RestoranID
WHERE r.IsActive = 1 AND y.IsActive = 1;
GO

CREATE NONCLUSTERED INDEX IX_Siparisler_SiparisTarihi ON Siparisler(SiparisTarihi);
CREATE NONCLUSTERED INDEX IX_Musteriler_Eposta ON Musteriler(Eposta);
GO

-- 4. REPORTING & ANALYTICS (DQL)
-- Order Details with Customer and Restaurant Info
SELECT s.SiparisID, m.Ad + ' ' + m.Soyad AS MusteriAdSoyad, r.RestoranAdi, s.SiparisTarihi, s.ToplamTutar
FROM Siparisler s
INNER JOIN Musteriler m ON s.MusteriID = m.MusteriID
INNER JOIN Restoranlar r ON s.RestoranID = r.RestoranID
ORDER BY s.SiparisTarihi DESC;

-- Average Cart Amount for Restaurants with >5 Orders
SELECT r.RestoranAdi, COUNT(s.SiparisID) AS ToplamSiparisAdedi, AVG(s.ToplamTutar) AS OrtalamaSepetTutari
FROM Restoranlar r
INNER JOIN Siparisler s ON r.RestoranID = s.RestoranID
GROUP BY r.RestoranAdi
HAVING COUNT(s.SiparisID) > 5;

-- Active Users with No Suspended Meal Donations
SELECT m.Ad, m.Soyad, m.Eposta
FROM Musteriler m
WHERE NOT EXISTS (
    SELECT 1 FROM AskidaYemekHavuzu a WHERE a.MusteriID = m.MusteriID
) AND m.IsVerified = 0;