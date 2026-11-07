"""Wandelt die beiden Excel-Dateien in CSV-Dateien für BULK INSERT um.

Die Excel-Dateien in data/ werden dabei nur gelesen, nicht verändert.
Ganzzahlige Spalten werden ohne ".0" geschrieben, damit SQL Server sie
direkt als BIGINT einlesen kann. Leere Zellen bleiben leer (-> NULL).

Aufruf aus dem Repo-Ordner:
    python scripts/xlsx_to_csv.py
"""

from pathlib import Path

import pandas as pd

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CSV_DIR = DATA_DIR / "csv"
FILES = ["CovidDeaths", "CovidVaccinations"]


def convert(name):
    df = pd.read_excel(DATA_DIR / f"{name}.xlsx")

    # Ganzzahlige Float-Spalten (Float nur wegen fehlender Werte) -> Int64
    for col in df.select_dtypes("float").columns:
        values = df[col].dropna()
        if (values == values.round()).all():
            df[col] = df[col].astype("Int64")

    df["date"] = pd.to_datetime(df["date"]).dt.strftime("%Y-%m-%d")

    out = CSV_DIR / f"{name}.csv"
    df.to_csv(out, index=False, encoding="utf-8", lineterminator="\n")
    print(f"{out.name}: {len(df)} Zeilen, {len(df.columns)} Spalten")


if __name__ == "__main__":
    CSV_DIR.mkdir(exist_ok=True)
    for name in FILES:
        convert(name)
