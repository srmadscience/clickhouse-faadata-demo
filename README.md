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
| `faa.registry_master`, `faa.registry_dereg`, `faa.registry_models` | [FAA aircraft registry](https://www.faa.gov/licenses_certificates/aircraft_certification/aircraft_registry/releasable_aircraft_download) | registered and deregistered aircraft; make/model reference |
| `faa.aircraft` (view), `faa.aircraft_info` (snapshot) | | one row per tail number: model, year built, seats, owner, status |
| `faa.flight_weather` | built from `ontime` + `weather` | one row per flight with UTC schedule times and the weather (flight category, wind, visibility, present weather) at origin and destination |

To join flights to weather, go through `faa.airport_station`: `ontime.Origin = airport`,
`weather.station = station`. Station ids differ from BTS codes outside the lower 48
(FAI → PAFA, SJU → TJSJ), and `sql/35_airport_aliases.sql` covers re-coded airports
(PBI → DJT) and closed ones (ISN, Williston, closed 2019). Saipan (SPN) has no IEM station.

Flights join to aircraft on `ontime.tail = aircraft_info.tail` (99.9% of 2025 tail numbers
match; aircraft retired since come from the deregistration file). Owner street addresses
are never loaded, and owner names only for organisations, not individuals.

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
| `fetch-stations.sh` / `load-stations.sh` | Gets IEM stations and OurAirports; lists airports with no station |
| `fetch-weather.sh FROM TO` | Downloads IEM observations (years) for every airport in `faa.ontime` |
| `load-weather.sh` | Loads them; duplicates are removed by the table engine |
| `build-flight-weather.sh` | Rebuilds `flight_weather`; re-run after loading flights, stations or weather |
| `fetch-registry.sh` / `load-registry.sh` | Gets the FAA registry; replaces the registry tables and `aircraft_info` |

The fetch scripts download from the project's [data mirror](#data-mirror) first and go
to the original sources only for what it lacks, so a full rebuild takes minutes, not hours.

To add more data later, run `reproduce.sh` with a wider range: existing downloads are skipped.
New months come from BTS if the mirror doesn't have them yet. To bring the current year's
weather, the station list or the registry up to date, use `--refresh`:

    scripts/fetch-weather.sh --refresh 2026 2026
    scripts/fetch-stations.sh --refresh
    scripts/fetch-registry.sh --refresh

## Data mirror

The original sources are slow (IEM weather alone takes about 10 hours at one request at a
time), so the raw files are also published as [GitHub Releases](https://github.com/srmadscience/clickhouse-faadata-demo/releases)
on this repository: public, free to download, and outside git itself.

| Release | Files |
|---------|-------|
| `data-flights` | `ontime_YYYY_MM.zip`, as downloaded from BTS |
| `data-weather` | `weather_YYYY.tar`: that year's `YYYY/STATION.csv.gz` files |
| `data-reference` | `stations.tar.gz` (IEM networks and OurAirports), `ReleasableAircraft_YYYYMMDD.zip` |

GitHub shows each file's SHA-256 and the fetch scripts check it. `DATA_REPO=owner/repo`
points them at a fork's releases instead, and `DATA_REPO=none` skips the mirror.

After fetching new data, update the mirror with:

    scripts/publish-data.sh              # DRY_RUN=1 to see what it would upload

It uses the `gh` CLI and uploads only files that are new or changed. The weather data
comes from the Iowa Environmental Mesonet, which asks to be credited; the other sources
are public domain.

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
| [Weather Impact](http://kolcheck:3000/d/faa-weather-impact) | Delays, cancellations and diversions by weather at origin and destination: flight category, present weather, wind, visibility, temperature; worst weather days |
| [Aircraft Reliability](http://kolcheck:3000/d/faa-aircraft-reliability) | Per tail number: carrier-caused cancellations and delays, utilisation, out-of-service gaps, reliability by model and age; drill into one aircraft's history and registration |

To add a dashboard: build it in Grafana, export it as JSON (Share > Export), save it in
`grafana/dashboards/`, commit, and re-run the script.

## Large data files

The data does not live in git: the repo holds the *recipe* (the scripts above),
the [data mirror](#data-mirror) holds a copy of the files, and `data/manifest.sha256`
can record checksums of exactly what was loaded.
