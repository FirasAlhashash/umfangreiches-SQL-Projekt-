/*
    01 – Datenbank und Tabellen anlegen

    Legt die Datenbank PortfolioProject und die beiden Tabellen an.
    Die Spalten entsprechen 1:1 den Excel-Dateien in data/.

    Datentypen:
    - Zählwerte (Fälle, Todesfälle, Impfdosen, Bevölkerung) als BIGINT.
      Die Weltbevölkerung (ca. 7,8 Mrd.) passt nicht mehr in INT.
    - Raten und geglättete Werte als DECIMAL(18, 3), in den Daten gibt es
      höchstens drei Nachkommastellen.

    Ein Primärschlüssel auf (location, date) wird erst in 03_datenqualitaet.sql
    gesetzt, nachdem geprüft wurde, dass es keine Duplikate gibt.
*/

IF DB_ID(N'PortfolioProject') IS NULL
    CREATE DATABASE PortfolioProject;
GO

USE PortfolioProject;
GO

DROP TABLE IF EXISTS dbo.CovidDeaths;
DROP TABLE IF EXISTS dbo.CovidVaccinations;
GO

CREATE TABLE dbo.CovidDeaths (
    iso_code                                 NVARCHAR(20),
    continent                                NVARCHAR(50),      -- NULL bei Aggregatzeilen (World, Europe, ...)
    location                                 NVARCHAR(100) NOT NULL,
    date                                     DATE          NOT NULL,
    total_cases                              BIGINT,
    new_cases                                BIGINT,
    new_cases_smoothed                       DECIMAL(18, 3),
    total_deaths                             BIGINT,
    new_deaths                               BIGINT,
    new_deaths_smoothed                      DECIMAL(18, 3),
    total_cases_per_million                  DECIMAL(18, 3),
    new_cases_per_million                    DECIMAL(18, 3),
    new_cases_smoothed_per_million           DECIMAL(18, 3),
    total_deaths_per_million                 DECIMAL(18, 3),
    new_deaths_per_million                   DECIMAL(18, 3),
    new_deaths_smoothed_per_million          DECIMAL(18, 3),
    reproduction_rate                        DECIMAL(18, 3),
    icu_patients                             BIGINT,
    icu_patients_per_million                 DECIMAL(18, 3),
    hosp_patients                            BIGINT,
    hosp_patients_per_million                DECIMAL(18, 3),
    weekly_icu_admissions                    DECIMAL(18, 3),
    weekly_icu_admissions_per_million        DECIMAL(18, 3),
    weekly_hosp_admissions                   DECIMAL(18, 3),
    weekly_hosp_admissions_per_million       DECIMAL(18, 3),
    new_tests                                BIGINT,
    total_tests                              BIGINT,
    total_tests_per_thousand                 DECIMAL(18, 3),
    new_tests_per_thousand                   DECIMAL(18, 3),
    new_tests_smoothed                       BIGINT,
    new_tests_smoothed_per_thousand          DECIMAL(18, 3),
    positive_rate                            DECIMAL(18, 3),
    tests_per_case                           DECIMAL(18, 3),
    tests_units                              NVARCHAR(50),
    total_vaccinations                       BIGINT,            -- verabreichte Dosen, kumuliert
    people_vaccinated                        BIGINT,            -- Personen mit mind. einer Dosis
    people_fully_vaccinated                  BIGINT,            -- Personen mit vollständiger Grundimmunisierung
    new_vaccinations                         BIGINT,            -- neu verabreichte Dosen (nicht Personen)
    new_vaccinations_smoothed                BIGINT,
    total_vaccinations_per_hundred           DECIMAL(18, 3),
    people_vaccinated_per_hundred            DECIMAL(18, 3),
    people_fully_vaccinated_per_hundred      DECIMAL(18, 3),
    new_vaccinations_smoothed_per_million    BIGINT,
    stringency_index                         DECIMAL(18, 3),
    population                               BIGINT,
    population_density                       DECIMAL(18, 3),
    median_age                               DECIMAL(18, 3),
    aged_65_older                            DECIMAL(18, 3),
    aged_70_older                            DECIMAL(18, 3),
    gdp_per_capita                           DECIMAL(18, 3),
    extreme_poverty                          DECIMAL(18, 3),
    cardiovasc_death_rate                    DECIMAL(18, 3),
    diabetes_prevalence                      DECIMAL(18, 3),
    female_smokers                           DECIMAL(18, 3),
    male_smokers                             DECIMAL(18, 3),
    handwashing_facilities                   DECIMAL(18, 3),
    hospital_beds_per_thousand               DECIMAL(18, 3),
    life_expectancy                          DECIMAL(18, 3),
    human_development_index                  DECIMAL(18, 3)
);
GO

-- Die Impf-Tabelle hat keine Bevölkerungsspalte, deshalb wird später gejoint.
CREATE TABLE dbo.CovidVaccinations (
    iso_code                                 NVARCHAR(20),
    continent                                NVARCHAR(50),
    location                                 NVARCHAR(100) NOT NULL,
    date                                     DATE          NOT NULL,
    new_tests                                BIGINT,
    total_tests                              BIGINT,
    total_tests_per_thousand                 DECIMAL(18, 3),
    new_tests_per_thousand                   DECIMAL(18, 3),
    new_tests_smoothed                       BIGINT,
    new_tests_smoothed_per_thousand          DECIMAL(18, 3),
    positive_rate                            DECIMAL(18, 3),
    tests_per_case                           DECIMAL(18, 3),
    tests_units                              NVARCHAR(50),
    total_vaccinations                       BIGINT,
    people_vaccinated                        BIGINT,
    people_fully_vaccinated                  BIGINT,
    new_vaccinations                         BIGINT,
    new_vaccinations_smoothed                BIGINT,
    total_vaccinations_per_hundred           DECIMAL(18, 3),
    people_vaccinated_per_hundred            DECIMAL(18, 3),
    people_fully_vaccinated_per_hundred      DECIMAL(18, 3),
    new_vaccinations_smoothed_per_million    BIGINT,
    stringency_index                         DECIMAL(18, 3),
    population_density                       DECIMAL(18, 3),
    median_age                               DECIMAL(18, 3),
    aged_65_older                            DECIMAL(18, 3),
    aged_70_older                            DECIMAL(18, 3),
    gdp_per_capita                           DECIMAL(18, 3),
    extreme_poverty                          DECIMAL(18, 3),
    cardiovasc_death_rate                    DECIMAL(18, 3),
    diabetes_prevalence                      DECIMAL(18, 3),
    female_smokers                           DECIMAL(18, 3),
    male_smokers                             DECIMAL(18, 3),
    handwashing_facilities                   DECIMAL(18, 3),
    hospital_beds_per_thousand               DECIMAL(18, 3),
    life_expectancy                          DECIMAL(18, 3),
    human_development_index                  DECIMAL(18, 3)
);
GO
