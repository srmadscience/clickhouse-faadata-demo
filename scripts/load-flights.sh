#!/usr/bin/env bash
# Loads BTS zips from data/raw/flights/ (or the files given) into faa.ontime.
# Each file holds exactly one month, and that month's partition is dropped
# before loading, so re-running never duplicates flights.
#
#   scripts/load-flights.sh
#   scripts/load-flights.sh data/raw/flights/ontime_2025_06.zip
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ch_check_connection
ensure_loader

files=("$@")
[[ ${#files[@]} -gt 0 ]] || files=("$PROJECT_DIR"/data/raw/flights/ontime_*.zip)
[[ -f "${files[0]}" ]] || { echo "No flight files found; run fetch-flights.sh first." >&2; exit 1; }

for f in "${files[@]}"; do
  [[ "$(basename "$f")" =~ ^ontime_([0-9]{4})_([0-9]{2})\.zip$ ]] \
    || { echo "error: unexpected file name $f" >&2; exit 1; }
  ch_query "ALTER TABLE faa.ontime DROP PARTITION ${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  # BTS lines end with a stray ',' (an unnamed extra column), hence skip_unknown_fields.
  java -jar "$LOADER_JAR" load faa.ontime --set input_format_skip_unknown_fields=1 "$f"
done

ch_query "SELECT toYYYYMM(FlightDate) AS month, count() AS flights FROM faa.ontime GROUP BY month ORDER BY month FORMAT PrettyCompact"
