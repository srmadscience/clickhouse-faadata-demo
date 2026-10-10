#!/usr/bin/env bash
# Replaces faa.stations and faa.airports with the files in data/raw/stations/,
# then reports BTS airports that have no matching IEM station (no weather).
#
#   scripts/load-stations.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ch_check_connection

files=("$PROJECT_DIR"/data/raw/stations/*.geojson)
[[ -f "${files[0]}" ]] || { echo "No station files found; run fetch-stations.sh first." >&2; exit 1; }

ch_query "TRUNCATE TABLE faa.stations"
python3 -I "$PROJECT_DIR/scripts/stations_to_csv.py" "${files[@]}" \
  | ch_insert "INSERT INTO faa.stations FORMAT CSV"
echo "Loaded $(ch_query "SELECT count() FROM faa.stations") stations"

ch_query "TRUNCATE TABLE faa.airports"
# OurAirports has extra columns (links, keywords) that faa.airports leaves out.
ch_insert "INSERT INTO faa.airports SETTINGS input_format_skip_unknown_fields = 1 FORMAT CSVWithNames" \
  < "$PROJECT_DIR/data/raw/stations/ourairports.csv"
echo "Loaded $(ch_query "SELECT count() FROM faa.airports") airports"

echo "BTS airports without an IEM station:"
ch_query "
  SELECT airport, any(state) AS state, count() AS flights
  FROM (SELECT Origin AS airport, OriginState AS state FROM faa.ontime)
  WHERE airport NOT IN (SELECT airport FROM faa.airport_station)
  GROUP BY airport ORDER BY flights DESC
  FORMAT PrettyCompact"
