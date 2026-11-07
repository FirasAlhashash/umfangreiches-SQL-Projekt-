"""Rechnet die Ergebnisse der drei Analysefragen unabhängig von SQL nach.

Liest direkt die Excel-Dateien aus data/ und wendet dieselbe Logik wie
05_auswertung_stichtag.sql an: pro Land der letzte gemeldete Wert bis zum
Stichtag, nur Länderzeilen, keine Aggregatzeilen.

Aufruf aus dem Repo-Ordner:
    python scripts/check_results.py
"""

from pathlib import Path

import pandas as pd

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
STICHTAG = pd.Timestamp("2021-04-30")


def last_value(df, col):
    rows = df.dropna(subset=[col]).sort_values("date").groupby("location").last()
    return rows[[col, "date"]].rename(columns={"date": f"{col}_date"})


def country_snapshot():
    deaths = pd.read_excel(DATA_DIR / "CovidDeaths.xlsx")
    vacc = pd.read_excel(DATA_DIR / "CovidVaccinations.xlsx")

    deaths = deaths[deaths["continent"].notna() & (deaths["date"] <= STICHTAG)]
    vacc = vacc[vacc["continent"].notna() & (vacc["date"] <= STICHTAG)]

    snap = deaths.groupby("location").agg(
        continent=("continent", "first"), population=("population", "first")
    )
    snap = snap.join(last_value(deaths, "total_cases")[["total_cases"]])
    snap = snap.join(last_value(deaths, "total_deaths")[["total_deaths"]])
    snap = snap.join(last_value(vacc, "total_vaccinations")[["total_vaccinations"]])
    snap = snap.join(last_value(vacc, "people_vaccinated"))
    snap = snap.join(last_value(vacc, "people_fully_vaccinated")[["people_fully_vaccinated"]])
    return snap


def main():
    snap = country_snapshot()
    pd.set_option("display.width", 120)

    print("Frage 1: Todesfälle nach Kontinent")
    known_pop = snap[snap["population"].notna()]
    q1 = pd.DataFrame({
        "total_deaths": snap.groupby("continent")["total_deaths"].sum(),
        "highest_single_country": snap.groupby("continent")["total_deaths"].max(),
        "deaths_per_100k": known_pop.groupby("continent")["total_deaths"].sum()
        * 100_000 / known_pop.groupby("continent")["population"].sum(),
    })
    print(q1.sort_values("total_deaths", ascending=False).round(1).to_string(), "\n")

    print("Frage 2: Fallsterblichkeitsquote")
    cases, deaths = snap["total_cases"].sum(), snap["total_deaths"].sum()
    print(f"Welt (Summe der Länder): {cases:,.0f} Fälle, {deaths:,.0f} Todesfälle, "
          f"{deaths / cases * 100:.2f} %")
    cfr = snap[snap["total_cases"] >= 10_000].assign(
        case_fatality_rate_pct=lambda x: x["total_deaths"] / x["total_cases"] * 100
    )
    cols = ["total_cases", "total_deaths", "case_fatality_rate_pct"]
    print(cfr.sort_values("case_fatality_rate_pct", ascending=False)[cols].head(10).round(2).to_string())
    print(cfr.loc[["Germany"], cols].round(2).to_string(), "\n")

    print("Frage 3: Geimpfte Personen vs. Dosen (Länder ab 1 Mio. Einwohner)")
    big = snap[snap["population"] >= 1_000_000].copy()
    big["pct_at_least_one_dose"] = big["people_vaccinated"] / big["population"] * 100
    big["pct_fully_vaccinated"] = big["people_fully_vaccinated"] / big["population"] * 100
    big["doses_per_100"] = big["total_vaccinations"] / big["population"] * 100
    big["people_vaccinated_date"] = big["people_vaccinated_date"].dt.strftime("%Y-%m-%d")
    cols = ["people_vaccinated_date", "pct_at_least_one_dose", "pct_fully_vaccinated", "doses_per_100"]
    top = big.dropna(subset=["pct_at_least_one_dose"])
    print(top.sort_values("pct_at_least_one_dose", ascending=False)[cols].head(10).round(1).to_string())
    print(big.loc[["Germany"], cols].round(1).to_string())


if __name__ == "__main__":
    main()
