# clickhouse-faadata-demo
A ClickHouse / Grafana application that uses publicly available FAA flight and weather data.

* **ClickHouse**: `xraytunnel` (HTTP 8123, native 9000), database `faa`
* **Loader**: Java 21 / Maven, ClickHouse `client-v2`
* **Dashboards**: Grafana 13 on `kolcheck` (10.13.1.142:3000) with the `grafana-clickhouse-datasource` plugin

## Data

| Table | Source | Grain |
|-------|--------|-------|
| `faa.ontime` | [BTS on-time performance](https://www.transtats.bts.gov/) | one row per scheduled flight; times are airport-local |
| `faa.stations` | [IEM](https://mesonet.agron.iastate.edu/) ASOS station metadata | one row per weather station, incl. time zone |
| `faa.weather` | [IEM ASOS](https://mesonet.agron.iastate.edu/request/download.phtml) observations | one row per METAR (roughly hourly), UTC |
| `faa.airports` | [OurAirports](https://ourairports.com/data/) | one row per airport worldwide: codes, names, coordinates |
| `faa.airport_station` (view) | | BTS airport code → IEM station and time zone |

To join flights to weather, go through `faa.airport_station`: `ontime.Origin = airport`,
`weather.station = station`. Station ids differ from BTS codes outside the lower 48
(FAI → PAFA, SJU → TJSJ), and `sql/35_airport_aliases.sql` covers re-coded airports
(PBI → DJT). Saipan (SPN) has no IEM station.

## Layout

    src/main/java/...      Loader: ping | schema | load (streams CSV / .gz / .zip)
    sql/                   Table definitions, run in file-name order
    scripts/               Everything needed to rebuild the database and Grafana (below)
    grafana/provisioning/  Datasource + dashboard provider config
    grafana/dashboards/    Exported dashboard JSON (committed)
    data/                  Downloaded data: NOT in git (see data/README.md)

## Reproducing the database

Needs bash, curl, python3, Java 21 and Maven.

    cp clickhouse.properties.example clickhouse.properties   # add the password
    scripts/reproduce.sh 2025-01 2025-12

`reproduce.sh` runs these steps in order. Each is safe to re-run, and can be run on its own:

| Script | Does |
|--------|------|
| `create-database.sh` | Creates `faa` and the tables from `sql/` |
| `fetch-flights.sh FROM TO` | Downloads BTS months (`YYYY-MM`) not already in `data/raw/flights/` |
| `load-flights.sh` | Loads them, replacing each month's partition |
| `fetch-stations.sh` / `load-stations.sh` | Refreshes IEM stations and OurAirports; lists airports with no station |
| `fetch-weather.sh FROM TO` | Downloads IEM observations (years) for every airport in `faa.ontime` |
| `load-weather.sh` | Loads them; duplicates are removed by the table engine |

To add more data later, run `reproduce.sh` with a wider range: existing downloads are skipped.

## Grafana

Grafana runs on kolcheck (http://kolcheck:3000) and queries ClickHouse (xraytunnel:9000)
directly. Set it up, or update it after changing `grafana/`, with:

    scripts/grafana-provision.sh

This uses SSH (`pi@kolcheck`, key login and passwordless sudo) to install the
datasource and dashboard provider from `grafana/provisioning/`, copy
`grafana/dashboards/*.json`, put the ClickHouse credentials in a root-only
`/etc/grafana/faa-clickhouse.env`, and restart Grafana. The datasource is
"ClickHouse FAA" (uid `clickhouse-faa`); being provisioned, it is read-only in the UI.

Dashboards (folder "FAA"):

| Dashboard | Shows |
|-----------|-------|
| [Flight Delays](http://kolcheck:3000/d/faa-flight-delays) | On-time %, delays and cancellations over time, delay causes, airlines, hour/weekday patterns, airport map |
| [Aircraft Reliability](http://kolcheck:3000/d/faa-aircraft-reliability) | Per tail number: carrier-caused cancellations and delays, utilisation, out-of-service gaps; drill into one aircraft's history |

To add a dashboard: build it in Grafana, export it as JSON (Share > Export), save it in
`grafana/dashboards/`, commit, and re-run the script.

## Large data files

The data does not live in git: the repo holds the *recipe* (the scripts above),
and `data/manifest.sha256` can record checksums of exactly what was loaded.
