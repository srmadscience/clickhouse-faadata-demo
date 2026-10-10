#!/usr/bin/env bash
# Rebuilds everything from scratch, in order: schema, flights, stations, weather,
# aircraft registry.
# Every step is idempotent, so this is also the way to extend the date range.
#
#   scripts/reproduce.sh 2025-01 2025-12
set -euo pipefail
cd "$(dirname "$0")"

[[ $# -eq 2 ]] || { echo "usage: $0 FROM_YYYY-MM TO_YYYY-MM" >&2; exit 1; }

./create-database.sh
./fetch-flights.sh "$1" "$2"
./load-flights.sh
./fetch-stations.sh
./load-stations.sh
./fetch-weather.sh "${1%-*}" "${2%-*}"
./load-weather.sh
./fetch-registry.sh
./load-registry.sh
