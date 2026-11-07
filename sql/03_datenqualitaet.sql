/*
    03 – Datenqualität prüfen

    Bevor ausgewertet wird:
    1. Umfang und Zeitraum
    2. Aggregatzeilen (continent ist NULL)
    3. Doppelte Kombinationen aus Land und Datum, danach Primärschlüssel
    4. Join der beiden Tabellen: passen die Zeilen 1:1 zusammen?
    5. Fehlende Werte in den Spalten, die später benutzt werden
    6. Auffällige Werte (negative Tageswerte, Bevölkerung)
    7. Welche Länder am Stichtag keinen Wert haben
    8. new_vaccinations aufsummiert vs. total_vaccinations
*/

USE PortfolioProject;
GO

DECLARE @stichtag DATE = '2021-04-30';


-- 1. Umfang und Zeitraum ----------------------------------------------------

SELECT
    COUNT(*)                                                     AS row_count,
    MIN(date)                                                    AS first_date,
    MAX(date)                                                    AS last_date,
    COUNT(DISTINCT CASE WHEN continent IS NOT NULL THEN location END) AS countries,
    COUNT(DISTINCT CASE WHEN continent IS NULL     THEN location END) AS aggregate_rows
FROM dbo.CovidDeaths;


-- 2. Aggregatzeilen ---------------------------------------------------------
-- Bei Zeilen ohne Kontinent steht in location ein Kontinent, die Welt, die EU
-- oder "International". Die dürfen nicht zusammen mit den Ländern summiert
-- werden, sonst wird doppelt gezählt.

SELECT location, COUNT(*) AS days
FROM dbo.CovidDeaths
WHERE continent IS NULL OR continent = ''
GROUP BY location
ORDER BY location;


-- 3. Doppelte Kombinationen aus Land und Datum ------------------------------

SELECT 'CovidDeaths' AS table_name, location, date, COUNT(*) AS n
FROM dbo.CovidDeaths
GROUP BY location, date
HAVING COUNT(*) > 1
UNION ALL
SELECT 'CovidVaccinations', location, date, COUNT(*)
FROM dbo.CovidVaccinations
GROUP BY location, date
HAVING COUNT(*) > 1;
-- Ergebnis: keine Zeilen, also keine Duplikate.

-- Nur wenn es keine Duplikate gibt, wird (location, date) zum Primärschlüssel.
-- Dann kann der Join unten auch keine Zeilen vervielfachen.
IF NOT EXISTS (SELECT 1 FROM dbo.CovidDeaths GROUP BY location, date HAVING COUNT(*) > 1)
   AND OBJECT_ID(N'dbo.PK_CovidDeaths') IS NULL
    ALTER TABLE dbo.CovidDeaths ADD CONSTRAINT PK_CovidDeaths PRIMARY KEY (location, date);

IF NOT EXISTS (SELECT 1 FROM dbo.CovidVaccinations GROUP BY location, date HAVING COUNT(*) > 1)
   AND OBJECT_ID(N'dbo.PK_CovidVaccinations') IS NULL
    ALTER TABLE dbo.CovidVaccinations ADD CONSTRAINT PK_CovidVaccinations PRIMARY KEY (location, date);


-- 4. Join prüfen ------------------------------------------------------------
-- Wenn der Join 1:1 ist, hat das Ergebnis genauso viele Zeilen wie jede
-- Tabelle für sich, und es bleiben auf keiner Seite Zeilen übrig.

SELECT
    (SELECT COUNT(*) FROM dbo.CovidDeaths)       AS deaths_rows,
    (SELECT COUNT(*) FROM dbo.CovidVaccinations) AS vaccinations_rows,
    (SELECT COUNT(*)
     FROM dbo.CovidDeaths dea
     JOIN dbo.CovidVaccinations vac
         ON dea.location = vac.location
        AND dea.date     = vac.date)              AS joined_rows,
    (SELECT COUNT(*)
     FROM dbo.CovidDeaths dea
     LEFT JOIN dbo.CovidVaccinations vac
         ON dea.location = vac.location
        AND dea.date     = vac.date
     WHERE vac.location IS NULL)                  AS deaths_without_match,
    (SELECT COUNT(*)
     FROM dbo.CovidVaccinations vac
     LEFT JOIN dbo.CovidDeaths dea
         ON dea.location = vac.location
        AND dea.date     = vac.date
     WHERE dea.location IS NULL)                  AS vaccinations_without_match;

-- In dieser Version der Daten stehen die Impfspalten auch in CovidDeaths.
-- Stimmen sie mit CovidVaccinations überein?
SELECT COUNT(*) AS rows_with_different_vaccination_values
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE ISNULL(dea.new_vaccinations, -1)        <> ISNULL(vac.new_vaccinations, -1)
   OR ISNULL(dea.total_vaccinations, -1)      <> ISNULL(vac.total_vaccinations, -1)
   OR ISNULL(dea.people_vaccinated, -1)       <> ISNULL(vac.people_vaccinated, -1)
   OR ISNULL(dea.people_fully_vaccinated, -1) <> ISNULL(vac.people_fully_vaccinated, -1);


-- 5. Fehlende Werte (nur Länderzeilen) ----------------------------------------

SELECT
    COUNT(*)                                                   AS country_rows,
    SUM(CASE WHEN dea.population              IS NULL THEN 1 ELSE 0 END) AS missing_population,
    SUM(CASE WHEN dea.total_cases             IS NULL THEN 1 ELSE 0 END) AS missing_total_cases,
    SUM(CASE WHEN dea.new_cases               IS NULL THEN 1 ELSE 0 END) AS missing_new_cases,
    SUM(CASE WHEN dea.total_deaths            IS NULL THEN 1 ELSE 0 END) AS missing_total_deaths,
    SUM(CASE WHEN dea.new_deaths              IS NULL THEN 1 ELSE 0 END) AS missing_new_deaths,
    SUM(CASE WHEN vac.new_vaccinations        IS NULL THEN 1 ELSE 0 END) AS missing_new_vaccinations,
    SUM(CASE WHEN vac.total_vaccinations      IS NULL THEN 1 ELSE 0 END) AS missing_total_vaccinations,
    SUM(CASE WHEN vac.people_vaccinated       IS NULL THEN 1 ELSE 0 END) AS missing_people_vaccinated,
    SUM(CASE WHEN vac.people_fully_vaccinated IS NULL THEN 1 ELSE 0 END) AS missing_people_fully_vaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL;

-- Länder, die nie einen Wert gemeldet haben
SELECT
    dea.location,
    MAX(dea.population)         AS population,
    MAX(dea.total_cases)        AS max_total_cases,
    MAX(dea.total_deaths)       AS max_total_deaths,
    MAX(vac.people_vaccinated)  AS max_people_vaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location
HAVING MAX(dea.total_cases) IS NULL
    OR MAX(dea.total_deaths) IS NULL
    OR MAX(vac.people_vaccinated) IS NULL
ORDER BY dea.location;


-- 6. Auffällige Werte -------------------------------------------------------

-- Negative Tageswerte entstehen durch nachträgliche Korrekturen der Meldestellen.
SELECT
    SUM(CASE WHEN new_cases  < 0 THEN 1 ELSE 0 END) AS negative_new_cases,
    SUM(CASE WHEN new_deaths < 0 THEN 1 ELSE 0 END) AS negative_new_deaths
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;

-- Bevölkerung muss pro Land konstant sein, sonst stimmen die Quoten nicht.
SELECT location, COUNT(DISTINCT population) AS distinct_population_values
FROM dbo.CovidDeaths
GROUP BY location
HAVING COUNT(DISTINCT population) > 1 OR MAX(population) IS NULL;


-- 7. Stichtag ---------------------------------------------------------------
-- Nicht jedes Land hat am Stichtag eine Zeile bzw. einen Wert. Deshalb wird
-- in 05_auswertung_stichtag.sql pro Land der letzte gemeldete Wert bis
-- einschließlich Stichtag genommen.

SELECT
    c.location,
    MAX(c.date)                                              AS last_row_date,
    MAX(CASE WHEN c.total_deaths IS NOT NULL THEN c.date END) AS last_total_deaths_date
FROM dbo.CovidDeaths c
WHERE c.continent IS NOT NULL
  AND c.date <= @stichtag
GROUP BY c.location
HAVING MAX(c.date) < @stichtag
    OR MAX(CASE WHEN c.total_deaths IS NOT NULL THEN c.date END) IS NULL
    OR MAX(CASE WHEN c.total_deaths IS NOT NULL THEN c.date END) < @stichtag
ORDER BY c.location;


-- 8. new_vaccinations vs. total_vaccinations ---------------------------------
-- new_vaccinations sind neu verabreichte Dosen pro Tag. Die Spalte ist an
-- Tagen ohne Meldung leer, deshalb ist die Summe kleiner als der letzte
-- Stand von total_vaccinations. Eine laufende Summe über new_vaccinations
-- ist also nur eine Näherung für die verabreichten Dosen.

SELECT TOP (10)
    location,
    SUM(new_vaccinations)                                         AS sum_new_vaccinations,
    MAX(total_vaccinations)                                       AS max_total_vaccinations,
    MAX(total_vaccinations) - SUM(new_vaccinations)               AS difference
FROM dbo.CovidVaccinations
WHERE continent IS NOT NULL
GROUP BY location
HAVING MAX(total_vaccinations) IS NOT NULL
ORDER BY MAX(total_vaccinations) - SUM(new_vaccinations) DESC;
