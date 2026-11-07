# COVID-19 Datenexploration mit SQL Server

SQL-Projekt mit den weltweiten COVID-19-Daten von Our World in Data: Fälle, Todesfälle und Impfungen nach Ländern und Kontinenten, Zeitraum 01.01.2020 bis 30.04.2021.

Die erste Version habe ich nach dem Tutorial *Data Analyst Portfolio Project | SQL Data Exploration* von Alex The Analyst gebaut ([Video](https://www.youtube.com/watch?v=qfyynHBFOsM), [Original-SQL und Daten](https://github.com/AlexTheAnalyst/PortfolioProjects)). Später habe ich das Projekt überarbeitet, weil einige Abfragen inhaltlich falsch waren:

- Die Kontinent-Auswertung hat mit `MAX(total_deaths)` nur das Land mit den meisten Todesfällen gezeigt, nicht die Summe. Für Europa kamen so 127.775 statt 1.016.750 Todesfälle heraus.
- Die laufende Summe von `new_vaccinations` hieß „RollingPeopleVaccinated“. Die Spalte zählt aber Impfdosen, nicht geimpfte Personen.
- `CONVERT(int, ...)` läuft bei großen Summen über (die Weltbevölkerung allein sind 7,8 Mrd.), und Divisionen waren nicht gegen 0 abgesichert.
- Todesfälle/Fälle war als „Wahrscheinlichkeit, an Covid zu sterben“ beschrieben. Richtig ist Fallsterblichkeitsquote.

Neu dazugekommen sind ein reproduzierbarer Import, eine Datenqualitätsprüfung und drei Analysefragen. Die Ergebnisse habe ich in SQL Server ausgeführt und zusätzlich mit Python nachgerechnet.

## Daten

| | |
|---|---|
| Quelle | [Our World in Data, COVID-19-Datensatz](https://github.com/owid/covid-19-data) (CC BY 4.0), als Excel-Dateien aus dem Tutorial-Repo |
| Zeitraum | 01.01.2020 bis 30.04.2021 |
| Umfang | je 85.171 Zeilen, 210 Länder und 9 Aggregatzeilen |
| `CovidDeaths.xlsx` | Fälle, Todesfälle, Bevölkerung (59 Spalten) |
| `CovidVaccinations.xlsx` | Tests und Impfungen (37 Spalten, ohne Bevölkerung) |

Die Excel-Dateien in `data/` sind unverändert.

Zwei Sachen in den Daten muss man kennen, sonst rechnet man falsch:

- **Aggregatzeilen:** Bei Zeilen ohne `continent` steht in `location` ein Kontinent, „World“, „European Union“ oder „International“. Wenn man diese Zeilen mit den Ländern summiert, wird alles doppelt gezählt. Alle Auswertungen hier nehmen nur Länderzeilen (`continent IS NOT NULL`).
- **Dosen vs. Personen:** `new_vaccinations` und `total_vaccinations` zählen Impfdosen. Für Quoten geimpfter Menschen gibt es eigene Spalten: `people_vaccinated` (mindestens eine Dosis) und `people_fully_vaccinated`.

## Aufbau

```
data/                         Originaldaten (Excel), unverändert
scripts/xlsx_to_csv.py        Excel -> CSV für den Import
scripts/check_results.py      Ergebnisse unabhängig mit pandas nachrechnen
sql/01_tabellen_anlegen.sql   Datenbank und Tabellen mit festen Datentypen
sql/02_import.sql             CSV-Import mit BULK INSERT
sql/03_datenqualitaet.sql     Duplikate, Join-Prüfung, fehlende Werte, Stichtag
sql/04_exploration.sql        Zeitverläufe, laufende Summe der Impfdosen (Window Function, CTE, Temp-Tabelle)
sql/05_auswertung_stichtag.sql  Länder, Kontinente, Welt zum 30.04.2021 und die drei Analysefragen
sql/06_views.sql              Views für Tableau
```

## Setup und Import

Getestet mit SQL Server 2022 Developer Edition und `sqlcmd` 16, Python 3.11.

1. **SQL Server installieren**, z. B. die kostenlose [Developer Edition](https://www.microsoft.com/de-de/sql-server/sql-server-downloads), dazu SSMS oder nur `sqlcmd`.

2. **CSV-Dateien erzeugen.** SQL Server kann Excel nicht ohne zusätzliche Treiber lesen, deshalb gehen die Daten über CSV:

   ```bash
   pip install -r requirements.txt
   python scripts/xlsx_to_csv.py
   ```

   Das legt `data/csv/CovidDeaths.csv` und `data/csv/CovidVaccinations.csv` an (UTF-8, ganze Zahlen ohne „.0“, leere Zellen bleiben leer und werden zu NULL).

3. **Skripte der Reihe nach ausführen** (im Repo-Ordner, Windows-Authentifizierung):

   ```bat
   sqlcmd -S localhost -E -f 65001 -i sql\01_tabellen_anlegen.sql
   sqlcmd -S localhost -E -f 65001 -i sql\02_import.sql -v csv_dir="%CD%\data\csv"
   sqlcmd -S localhost -E -f 65001 -i sql\03_datenqualitaet.sql
   sqlcmd -S localhost -E -f 65001 -i sql\04_exploration.sql
   sqlcmd -S localhost -E -f 65001 -i sql\05_auswertung_stichtag.sql
   sqlcmd -S localhost -E -f 65001 -i sql\06_views.sql
   ```

   `-f 65001` sorgt dafür, dass die UTF-8-Dateien richtig gelesen werden. In SSMS muss für `02_import.sql` der SQLCMD-Modus an sein, und die `:setvar`-Zeile im Skript muss angepasst werden. Wenn BULK INSERT „Zugriff verweigert“ meldet, darf der SQL-Server-Dienst den Ordner nicht lesen. Dann den `csv`-Ordner z. B. nach `C:\Users\Public\` kopieren.

4. **Optional nachrechnen:** `python scripts/check_results.py` rechnet die Ergebnisse der drei Fragen direkt aus den Excel-Dateien nach.

Die Datentypen sind fest vorgegeben: Zählwerte als `BIGINT`, Raten als `DECIMAL(18, 3)`. Prozentwerte werden mit `* 100.0` in Dezimalzahlen gerechnet und der Nenner mit `NULLIF(..., 0)` abgesichert.

## Datenqualität

Ergebnisse aus `03_datenqualitaet.sql`:

- **Duplikate:** Keine doppelte Kombination aus Land und Datum, in keiner der beiden Tabellen. Danach wird `(location, date)` als Primärschlüssel gesetzt.
- **Join:** 85.171 Zeilen in jeder Tabelle und 85.171 nach dem Join, auf keiner Seite bleiben Zeilen übrig. Der Join vervielfacht also nichts.
- **Fehlende Werte:** Bei den Impfspalten fehlt viel. Das liegt daran, dass die Impfungen erst Ende 2020 begonnen haben, und viele Länder melden nicht täglich. Von 81.060 Länderzeilen haben 74.062 kein `new_vaccinations`. Bei 49 Ländern fehlt eine der Kennzahlen komplett. Zum Beispiel haben China und Saudi-Arabien keine Personenzahlen zur Impfung, und Hongkong hat nur Impfdaten.
- **Bevölkerung:** Sie ist pro Land konstant. Nur für „International“ und Nordzypern fehlt sie.
- **Negative Tageswerte:** 61 Tage mit negativen neuen Fällen und 80 mit negativen neuen Todesfällen, das sind Korrekturen der Meldestellen.
- **Laufende Summe der Dosen:** Die Summe über `new_vaccinations` liegt unter `total_vaccinations`, weil Tage ohne Meldung fehlen. Bei China sind es rund 80 Mio. Dosen. Die laufende Summe aus dem Tutorial ist also nur eine Näherung.

## Analysefragen

Stichtag ist der 30.04.2021, der letzte Tag in den Daten. Pro Land wird der letzte gemeldete Wert bis zum Stichtag genommen. Bei Fällen und Todesfällen ist das bei allen Ländern genau der 30.04., bei den Impfzahlen manchmal ein paar Tage früher. Kontinente und Welt sind Summen der Länder.

Alle Zahlen unten habe ich mit `05_auswertung_stichtag.sql` in SQL Server ausgeführt und mit `scripts/check_results.py` unabhängig nachgerechnet. Beide Wege kommen auf dieselben Werte. Als zusätzliche Kontrolle stimmen die Kontinent-Summen exakt mit den Kontinentzeilen in den Originaldaten überein.

### 1. Welche Kontinente hatten die meisten Todesfälle, absolut und pro 100.000 Einwohner?

| Kontinent | Todesfälle | pro 100.000 Einw. | Land mit den meisten (alte MAX-Abfrage) |
|---|---:|---:|---:|
| Europa | 1.016.750 | 135,3 | 127.775 |
| Nordamerika | 847.942 | 144,2 | 576.232 |
| Südamerika | 672.415 | 156,2 | 403.781 |
| Asien | 520.286 | 11,3 | 211.853 |
| Afrika | 121.784 | 9,1 | 54.350 |
| Ozeanien | 1.046 | 2,5 | 910 |

Absolut liegt Europa vorne. Bezogen auf die Bevölkerung war Südamerika am stärksten betroffen, vor Nordamerika und Europa. Asien liegt absolut auf Platz 4, pro Kopf aber mehr als zehnmal niedriger als Europa. Wie verlässlich die Meldungen in den einzelnen Ländern sind, lässt sich mit diesen Daten nicht prüfen. Die alte Abfrage hätte Nordamerika vorne gezeigt, nur weil die USA das Land mit den meisten Todesfällen sind.

### 2. Wie hoch war die Fallsterblichkeitsquote weltweit und wo war sie am höchsten?

Fallsterblichkeitsquote = gemeldete Todesfälle / gemeldete Fälle. Sie sagt nicht, wie wahrscheinlich eine infizierte Person stirbt. Wo wenig getestet wird, fehlen vor allem milde Fälle, und die Quote fällt höher aus.

- **Welt:** 3.180.223 Todesfälle bei 151.398.759 Fällen, das sind **2,10 %**. Die World-Zeile der Originaldaten liegt um 721 Fälle und 15 Todesfälle höher. Das ist genau die Zeile „International“ (Kreuzfahrtschiffe), die keinem Land zugeordnet ist.
- **Deutschland:** 2,44 %

Die höchsten Quoten hatten, bei mindestens 10.000 gemeldeten Fällen:

| Land | Fälle | Todesfälle | Fallsterblichkeitsquote |
|---|---:|---:|---:|
| Mexiko | 2.344.755 | 216.907 | 9,25 % |
| Syrien | 22.733 | 1.592 | 7,00 % |
| Sudan | 33.944 | 2.349 | 6,92 % |
| Ägypten | 227.552 | 13.339 | 5,86 % |
| Somalia | 13.915 | 713 | 5,12 % |

Mexiko fällt am meisten auf: Bei über 2 Mio. Fällen ist die Quote mehr als viermal so hoch wie weltweit. Das passt eher zu wenigen Tests als zu einem viel höheren Risiko. Belegen lässt sich das mit diesen Daten allein aber nicht.

### 3. Wie viele Menschen waren geimpft, und wie unterscheidet sich das von den verabreichten Dosen?

Länder ab 1 Mio. Einwohner, die ersten fünf nach dem Anteil mit mindestens einer Dosis und Deutschland zum Vergleich:

| Land | Stand | mind. 1 Dosis | vollständig geimpft | Dosen pro 100 Einw. |
|---|---|---:|---:|---:|
| Israel | 30.04. | 62,4 % | 58,8 % | 121,3 |
| Vereinigte Arabische Emirate | 20.04. | 51,4 % | 38,8 % | 106,6 |
| Vereinigtes Königreich | 29.04. | 50,4 % | 21,4 % | 71,8 |
| USA | 30.04. | 43,8 % | 30,6 % | 72,6 |
| Chile | 29.04. | 42,2 % | 35,0 % | 77,3 |
| Deutschland | 29.04. | 26,7 % | 7,6 % | 34,3 |

Hier sieht man, warum Dosen und Personen getrennt bleiben müssen. Israel hat 121 Dosen pro 100 Einwohner, geimpft sind aber „nur“ 62 % der Menschen. Wer Dosen als Personen liest, kommt auf über 100 % geimpfte Bevölkerung. Diese Verwechslung steckte im Tutorial in der Spalte „RollingPeopleVaccinated“. Großbritannien hatte bei der Erstimpfung fast so viele Menschen erreicht wie die Emirate, aber deutlich weniger vollständig geimpft.

## Grenzen

- Ausgewertet werden gemeldete Zahlen. Dunkelziffer, unterschiedliche Testmengen und unterschiedliche Zählweisen bei Todesfällen sind nicht berücksichtigt.
- Die Daten enden am 30.04.2021, spätere Wellen und Impfungen fehlen.
- Die Bevölkerungszahlen sind ein fester Wert pro Land aus dem Datensatz.
- Die SQL-Skripte habe ich nur mit `sqlcmd` ausgeführt, nicht in SSMS.
