/*
    02 – CSV-Dateien importieren

    Vorher: python scripts/xlsx_to_csv.py  (erzeugt die CSV-Dateien in data\csv)

    Der Ordner wird als sqlcmd-Variable übergeben:
        sqlcmd -S localhost -E -f 65001 -i sql\02_import.sql -v csv_dir="C:\...\data\csv"

    In SSMS: Abfrage > SQLCMD-Modus aktivieren und die :setvar-Zeile unten
    einkommentieren und anpassen.

    BULK INSERT liest die Datei mit dem Konto des SQL-Server-Dienstes. Kommt
    "Zugriff verweigert", hat der Dienst auf den Ordner keine Leserechte.
    Dann den csv-Ordner z. B. nach C:\Users\Public\ kopieren.
*/

-- :setvar csv_dir "C:\Users\Public\covid_csv"

USE PortfolioProject;
GO

TRUNCATE TABLE dbo.CovidDeaths;
TRUNCATE TABLE dbo.CovidVaccinations;

BULK INSERT dbo.CovidDeaths
FROM '$(csv_dir)\CovidDeaths.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    CODEPAGE        = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);

BULK INSERT dbo.CovidVaccinations
FROM '$(csv_dir)\CovidVaccinations.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    CODEPAGE        = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO

-- Erwartet: jeweils 85.171 Zeilen
SELECT 'CovidDeaths' AS table_name, COUNT(*) AS row_count FROM dbo.CovidDeaths
UNION ALL
SELECT 'CovidVaccinations', COUNT(*) FROM dbo.CovidVaccinations;
