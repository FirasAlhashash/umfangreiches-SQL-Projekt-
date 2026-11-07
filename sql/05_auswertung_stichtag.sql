/*
    05 – Auswertung zum Stichtag 30.04.2021

    Stichtag ist der letzte Tag in den Daten. Für jedes Land wird der letzte
    gemeldete Wert bis einschließlich Stichtag genommen (bei Fällen und
    Todesfällen ist das in diesen Daten immer genau der 30.04.2021, bei den
    Impfzahlen melden manche Länder seltener).

    Kontinente und Welt werden aus den Länderwerten summiert. Die Aggregatzeilen
    (World, Europe, European Union, International, ...) werden dabei nicht
    mitgezählt, sonst wäre alles doppelt drin. Sie dienen nur zur Kontrolle.

    Die drei Analysefragen aus dem README sind mit "Frage 1/2/3" markiert.
*/

USE PortfolioProject;
GO


-- Hilfsfunktion: eine Zeile pro Land mit dem letzten Wert bis zum Stichtag ----

CREATE OR ALTER FUNCTION dbo.fn_country_snapshot (@stichtag DATE)
RETURNS TABLE
AS
RETURN
SELECT
    c.continent,
    c.location,
    c.population,
    cs.total_cases,
    dt.total_deaths,
    dt.date                      AS deaths_date,
    tv.total_vaccinations,       -- verabreichte Dosen
    pv.people_vaccinated,        -- Personen mit mind. einer Dosis
    pv.date                      AS people_vaccinated_date,
    fv.people_fully_vaccinated   -- Personen vollständig geimpft
FROM (
    SELECT DISTINCT continent, location, population
    FROM dbo.CovidDeaths
    WHERE continent IS NOT NULL
      AND date <= @stichtag
) c
OUTER APPLY (
    SELECT TOP (1) x.total_cases
    FROM dbo.CovidDeaths x
    WHERE x.location = c.location AND x.date <= @stichtag AND x.total_cases IS NOT NULL
    ORDER BY x.date DESC
) cs
OUTER APPLY (
    SELECT TOP (1) x.total_deaths, x.date
    FROM dbo.CovidDeaths x
    WHERE x.location = c.location AND x.date <= @stichtag AND x.total_deaths IS NOT NULL
    ORDER BY x.date DESC
) dt
OUTER APPLY (
    SELECT TOP (1) v.total_vaccinations
    FROM dbo.CovidVaccinations v
    WHERE v.location = c.location AND v.date <= @stichtag AND v.total_vaccinations IS NOT NULL
    ORDER BY v.date DESC
) tv
OUTER APPLY (
    SELECT TOP (1) v.people_vaccinated, v.date
    FROM dbo.CovidVaccinations v
    WHERE v.location = c.location AND v.date <= @stichtag AND v.people_vaccinated IS NOT NULL
    ORDER BY v.date DESC
) pv
OUTER APPLY (
    SELECT TOP (1) v.people_fully_vaccinated
    FROM dbo.CovidVaccinations v
    WHERE v.location = c.location AND v.date <= @stichtag AND v.people_fully_vaccinated IS NOT NULL
    ORDER BY v.date DESC
) fv;
GO


DECLARE @stichtag DATE = '2021-04-30';


-- Länder mit den meisten Todesfällen (absolut) ------------------------------

SELECT TOP (10)
    location,
    total_deaths
FROM dbo.fn_country_snapshot(@stichtag)
ORDER BY total_deaths DESC;


-- Länder mit den meisten Todesfällen pro 100.000 Einwohner ------------------
-- Nur Länder ab 1 Mio. Einwohner, bei Kleinststaaten schwankt der Wert stark.

SELECT TOP (10)
    location,
    population,
    total_deaths,
    CAST(total_deaths * 100000.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS deaths_per_100k
FROM dbo.fn_country_snapshot(@stichtag)
WHERE population >= 1000000
ORDER BY deaths_per_100k DESC;


-- Länder mit dem höchsten Anteil gemeldeter Fälle an der Bevölkerung -------

SELECT TOP (10)
    location,
    population,
    total_cases,
    CAST(total_cases * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 2)) AS reported_cases_pct_of_population
FROM dbo.fn_country_snapshot(@stichtag)
WHERE population >= 1000000
ORDER BY reported_cases_pct_of_population DESC;


-- Frage 1: Kontinente – Todesfälle absolut und pro 100.000 Einwohner --------
-- Früher: MAX(total_deaths) pro Kontinent. Das ist nur der Wert des Landes
-- mit den meisten Todesfällen (z. B. USA für Nordamerika), nicht die Summe.
-- Zum Vergleich steht dieser Wert als highest_single_country noch daneben.
--
-- Für die Rate pro 100.000 werden Zähler und Nenner nur über Länder mit
-- bekannter Bevölkerung gebildet. Länder ohne gemeldete Todesfälle zählen mit
-- ihrer Bevölkerung, aber mit 0 Todesfällen.

SELECT
    continent,
    COUNT(*)                         AS countries,
    COUNT(total_deaths)              AS countries_with_deaths_data,
    SUM(total_deaths)                AS total_deaths,
    MAX(total_deaths)                AS highest_single_country,
    SUM(population)                  AS population,
    CAST(SUM(CASE WHEN population IS NOT NULL THEN total_deaths END) * 100000.0
         / NULLIF(SUM(population), 0) AS DECIMAL(9, 1)) AS deaths_per_100k
FROM dbo.fn_country_snapshot(@stichtag)
GROUP BY continent
ORDER BY total_deaths DESC;

-- Kontrolle: Summe der Länder vs. Kontinentzeile aus den Originaldaten
WITH country_sum AS (
    SELECT continent, SUM(total_deaths) AS total_deaths
    FROM dbo.fn_country_snapshot(@stichtag)
    GROUP BY continent
)
SELECT
    s.continent,
    s.total_deaths      AS sum_of_countries,
    a.total_deaths      AS owid_aggregate_row,
    s.total_deaths - a.total_deaths AS difference
FROM country_sum s
LEFT JOIN dbo.CovidDeaths a
    ON a.location  = s.continent
   AND a.date      = @stichtag
   AND a.continent IS NULL
ORDER BY s.continent;


-- Frage 2: Fallsterblichkeitsquote weltweit und nach Land --------------------
-- Fallsterblichkeitsquote = gemeldete Todesfälle / gemeldete Fälle.
-- Sie beschreibt die gemeldeten Fälle, nicht das Risiko einer infizierten
-- Person: Wo wenig getestet wird, fehlen vor allem milde Fälle im Nenner,
-- und die Quote fällt höher aus.

-- Welt, aus den Ländern summiert, mit der World-Zeile als Kontrolle
SELECT
    'Summe der Länder'                AS source,
    SUM(total_cases)                  AS total_cases,
    SUM(total_deaths)                 AS total_deaths,
    CAST(SUM(total_deaths) * 100.0 / NULLIF(SUM(total_cases), 0) AS DECIMAL(9, 2)) AS case_fatality_rate_pct
FROM dbo.fn_country_snapshot(@stichtag)
UNION ALL
SELECT
    'World-Zeile (Kontrolle)',
    total_cases,
    total_deaths,
    CAST(total_deaths * 100.0 / NULLIF(total_cases, 0) AS DECIMAL(9, 2))
FROM dbo.CovidDeaths
WHERE location = 'World' AND date = @stichtag;

-- Länder mit der höchsten Quote, nur ab 10.000 gemeldeten Fällen
SELECT TOP (10)
    location,
    total_cases,
    total_deaths,
    CAST(total_deaths * 100.0 / NULLIF(total_cases, 0) AS DECIMAL(9, 2)) AS case_fatality_rate_pct
FROM dbo.fn_country_snapshot(@stichtag)
WHERE total_cases >= 10000
ORDER BY case_fatality_rate_pct DESC;

-- Deutschland zum Vergleich
SELECT
    location,
    total_cases,
    total_deaths,
    CAST(total_deaths * 100.0 / NULLIF(total_cases, 0) AS DECIMAL(9, 2)) AS case_fatality_rate_pct
FROM dbo.fn_country_snapshot(@stichtag)
WHERE location = 'Germany';


-- Frage 3: Geimpfte Personen vs. verabreichte Dosen -------------------------
-- Personenquoten nur aus den Personenspalten (people_vaccinated,
-- people_fully_vaccinated). total_vaccinations zählt Dosen und steht nur als
-- "Dosen pro 100 Einwohner" daneben, das kann über 100 liegen.
-- Nur Länder ab 1 Mio. Einwohner. Das Datum zeigt, von wann der Wert ist.

SELECT TOP (10)
    location,
    population,
    people_vaccinated_date,
    CAST(people_vaccinated       * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS pct_at_least_one_dose,
    CAST(people_fully_vaccinated * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS pct_fully_vaccinated,
    CAST(total_vaccinations      * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS doses_per_100
FROM dbo.fn_country_snapshot(@stichtag)
WHERE population >= 1000000
  AND people_vaccinated IS NOT NULL
ORDER BY pct_at_least_one_dose DESC;

-- Deutschland zum Vergleich
SELECT
    location,
    people_vaccinated_date,
    CAST(people_vaccinated       * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS pct_at_least_one_dose,
    CAST(people_fully_vaccinated * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS pct_fully_vaccinated,
    CAST(total_vaccinations      * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS doses_per_100
FROM dbo.fn_country_snapshot(@stichtag)
WHERE location = 'Germany';
