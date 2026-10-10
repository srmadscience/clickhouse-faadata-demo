# data/

Everything here except this README, `manifest.sha256` and the `.gitkeep`
placeholders is git-ignored. **Never commit data files.** The scripts in
`scripts/` are the record of where the data comes from; re-running them
re-creates this directory.

| Path | Source | Fetched by |
|------|--------|------------|
| `raw/flights/ontime_YYYY_MM.zip` | BTS Reporting Carrier On-Time Performance, one zip per month | `scripts/fetch-flights.sh` |
| `raw/stations/XX_ASOS.geojson` | IEM ASOS station metadata, one file per state network | `scripts/fetch-stations.sh` |
| `raw/stations/ourairports.csv` | OurAirports airport list (IATA/ICAO/FAA codes) | `scripts/fetch-stations.sh` |
| `raw/weather/YYYY/STATION.csv` | IEM ASOS observations, one file per airport per year | `scripts/fetch-weather.sh` |

Rough sizes: flights ~30 MB zipped (~600k rows) per month; weather ~2.5 MB
(~10k rows) per airport per year, ~350 airports.

To pin down exactly what was loaded:

    scripts/checksums.sh update    # commit data/manifest.sha256
    scripts/checksums.sh verify    # on another machine
