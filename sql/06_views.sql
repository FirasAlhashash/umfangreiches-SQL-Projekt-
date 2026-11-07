/*
    06 – Views für spätere Visualisierungen (z. B. Tableau Public)
*/

USE PortfolioProject;
GO

-- Verabreichte Impfdosen pro Land und Tag, mit laufender Summe.
-- Dosen, nicht Personen (siehe 04_exploration.sql, Abschnitt 5).
CREATE OR ALTER VIEW dbo.vw_rolling_vaccination_doses AS
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
WHERE dea.continent IS NOT NULL;
GO

-- Länderwerte zum Stichtag 30.04.2021 mit den Kennzahlen aus 05.
-- Braucht dbo.fn_country_snapshot aus 05_auswertung_stichtag.sql.
CREATE OR ALTER VIEW dbo.vw_country_snapshot_2021_04_30 AS
SELECT
    continent,
    location,
    population,
    total_cases,
    total_deaths,
    CAST(total_deaths * 100000.0 / NULLIF(population, 0)       AS DECIMAL(9, 1)) AS deaths_per_100k,
    CAST(total_deaths * 100.0 / NULLIF(total_cases, 0)         AS DECIMAL(9, 2)) AS case_fatality_rate_pct,
    people_vaccinated,
    people_fully_vaccinated,
    total_vaccinations                                                            AS total_doses,
    CAST(people_vaccinated * 100.0 / NULLIF(population, 0)       AS DECIMAL(9, 1)) AS pct_at_least_one_dose,
    CAST(people_fully_vaccinated * 100.0 / NULLIF(population, 0) AS DECIMAL(9, 1)) AS pct_fully_vaccinated,
    CAST(total_vaccinations * 100.0 / NULLIF(population, 0)      AS DECIMAL(9, 1)) AS doses_per_100
FROM dbo.fn_country_snapshot('2021-04-30');
GO
