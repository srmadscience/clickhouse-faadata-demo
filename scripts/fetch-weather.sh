#!/usr/bin/env bash
# Downloads IEM ASOS observations, one CSV per station per year, into
# data/raw/weather/YEAR/STATION.csv. By default the stations are those of every
# airport in faa.ontime, via faa.airport_station (so load flights and stations
# first). Completed years are skipped if present; the current year is always
# re-fetched because it is still growing.
#
#   scripts/fetch-weather.sh 2025 2025
#   scripts/fetch-weather.sh 2025 2025 ORD JFK
set -euo pipefail
source "$(dirname "$0")/lib.sh"

[[ $# -ge 2 ]] || { echo "usage: $0 FROM_YEAR TO_YEAR [STATION...]" >&2; exit 1; }
from=$1; to=$2; shift 2

if [[ $# -gt 0 ]]; then
  stations=("$@")
else
  ch_check_connection
  stations=($(ch_query "
    SELECT DISTINCT station FROM faa.airport_station
    WHERE airport IN (SELECT Origin FROM faa.ontime UNION DISTINCT SELECT Dest FROM faa.ontime)
    ORDER BY station"))
fi
[[ ${#stations[@]} -gt 0 ]] || { echo "No stations; load flights and stations first." >&2; exit 1; }
echo "${#stations[@]} stations, $from-$to"

this_year=$(date -u +%Y)
IEM="https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py"
# report_type 3/4 = routine + special METARs. trace=0.0001 keeps p01i numeric.
PARAMS="data=all&tz=Etc/UTC&format=onlycomma&latlon=yes&elev=yes&missing=empty&trace=0.0001&direct=no&report_type=3&report_type=4"

for year in $(seq "$from" "$to"); do
  for st in "${stations[@]}"; do
    target="$PROJECT_DIR/data/raw/weather/$year/$st.csv"
    if [[ -f "$target" && $year -lt $this_year ]]; then
      continue
    fi
    rm -f "$target"
    url="$IEM?station=$st&year1=$year&month1=1&day1=1&year2=$((year + 1))&month2=1&day2=1&$PARAMS"
    if download "$url" "$target"; then
      echo "fetch  $year/$st.csv  $(($(wc -l < "$target") - 1)) obs"
    else
      rm -f "$target.part"
      echo "warn: failed $year/$st" >&2
    fi
    sleep 1   # IEM asks for sequential, unhurried requests
  done
done
