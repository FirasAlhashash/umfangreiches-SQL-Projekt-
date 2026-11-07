/*
    04 – Exploration im Zeitverlauf

    Die Abfragen aus dem Tutorial, überarbeitet:
    - Divisionen mit NULLIF gegen Division durch 0 und in DECIMAL gerechnet
      (bei BIGINT / BIGINT würde SQL Server ganzzahlig teilen)
    - nur Länderzeilen (continent IS NOT NULL)
    - new_vaccinations als Impfdosen benannt, nicht als geimpfte Personen

    Auswertungen zu einem festen Stichtag (Länder, Kontinente, Welt) stehen in
    05_auswertung_stichtag.sql.
*/

USE PortfolioProject;
GO


-- 1. Ausgangsdaten ------------------------------------------------------------

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;


-- 2. Fallsterblichkeitsquote im Zeitverlauf (Deutschland) ---------------------
-- Gemeldete Todesfälle / gemeldete Fälle. Das ist keine persönliche
-- Sterbewahrscheinlichkeit: Die Quote hängt stark davon ab, wie viel getestet
-- wird, und Todesfälle werden erst Wochen nach den Fällen gemeldet.

SELECT
    location,
    date,
    total_cases,
    total_deaths,
    CAST(total_deaths * 100.0 / NULLIF(total_cases, 0) AS DECIMAL(9, 2)) AS case_fatality_rate_pct
FROM dbo.CovidDeaths
WHERE location = 'Germany'
ORDER BY date;


-- 3. Gemeldete Fälle im Verhältnis zur Bevölkerung (Deutschland) -------------
-- Gemeldete Fälle enthalten keine Dunkelziffer und können Reinfektionen
-- enthalten, deshalb "Anteil gemeldeter Fälle" und nicht "Anteil Infizierter".

SELECT
    location,
    date,
    population,
    total_cases,
    CAST(total_cases * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 3)) AS reported_cases_pct_of_population
FROM dbo.CovidDeaths
WHERE location = 'Germany'
ORDER BY date;


-- 4. Weltweite Tageswerte -----------------------------------------------------
-- Summe der Länder pro Tag, Aggregatzeilen ausgeschlossen.

SELECT
    date,
    SUM(new_cases)  AS new_cases,
    SUM(new_deaths) AS new_deaths
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date;


-- 5. Verabreichte Impfdosen, laufende Summe (Window Function) ---------------
-- new_vaccinations = neu verabreichte DOSEN pro Tag. Wer zweimal geimpft
-- wurde, steckt hier zweimal drin. Die laufende Summe ist deshalb keine Zahl
-- geimpfter Personen. Außerdem fehlen Tage ohne Meldung (siehe
-- 03_datenqualitaet.sql, Abschnitt 8), die Summe liegt also unter
-- total_vaccinations.

SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations AS new_doses,
    SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_doses
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;


-- 6. Dasselbe mit CTE, um mit der laufenden Summe weiterzurechnen -------------
-- Ergebnis: verabreichte Dosen pro 100 Einwohner (kann über 100 liegen).

WITH doses AS (
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations AS new_doses,
        SUM(vac.new_vaccinations) OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rolling_doses
    FROM dbo.CovidDeaths dea
    JOIN dbo.CovidVaccinations vac
        ON dea.location = vac.location
       AND dea.date     = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    *,
    CAST(rolling_doses * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 2)) AS rolling_doses_per_100
FROM doses
ORDER BY location, date;


-- 7. Dasselbe mit einer temporären Tabelle -----------------------------------

DROP TABLE IF EXISTS #DosesPerPopulation;

CREATE TABLE #DosesPerPopulation (
    continent      NVARCHAR(50),
    location       NVARCHAR(100),
    date           DATE,
    population     BIGINT,
    new_doses      BIGINT,
    rolling_doses  BIGINT
);

INSERT INTO #DosesPerPopulation
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL;

SELECT
    *,
    CAST(rolling_doses * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 2)) AS rolling_doses_per_100
FROM #DosesPerPopulation
ORDER BY location, date;
