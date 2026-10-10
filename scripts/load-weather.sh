#!/usr/bin/env bash
# Loads IEM CSVs from data/raw/weather/ (or the files/dirs given) into faa.weather.
# faa.weather is a ReplacingMergeTree keyed on (station, valid), so re-loading
# a file does not leave duplicates once ClickHouse merges.
#
#   scripts/load-weather.sh
#   scripts/load-weather.sh data/raw/weather/2025
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ch_check_connection
ensure_loader

paths=("$@")
[[ ${#paths[@]} -gt 0 ]] || paths=("$PROJECT_DIR/data/raw/weather")

# IEM timestamps are "YYYY-MM-DD hh:mm" (no seconds), hence best_effort parsing.
java -jar "$LOADER_JAR" load faa.weather --set date_time_input_format=best_effort "${paths[@]}"

ch_query "SELECT toYear(valid) AS year, uniqExact(station) AS stations, count() AS observations FROM faa.weather GROUP BY year ORDER BY year FORMAT PrettyCompact"
