#!/usr/bin/env bash
# Downloads BTS on-time performance files (one zip per month) into data/raw/flights/.
# Already-downloaded months are skipped, so it is safe to re-run.
#
#   scripts/fetch-flights.sh 2025-01 2025-12
#
# Source: https://www.transtats.bts.gov/ (Reporting Carrier On-Time Performance).
# BTS publishes with a lag of a few months; missing months are reported, not fatal.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

[[ $# -eq 2 ]] || { echo "usage: $0 FROM_YYYY-MM TO_YYYY-MM" >&2; exit 1; }
BASE_URL="https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present"
DEST="$PROJECT_DIR/data/raw/flights"

for ym in $(month_range "$1" "$2"); do
  y=${ym%-*}; m=$((10#${ym#*-}))
  target="$DEST/ontime_${y}_$(printf %02d "$m").zip"
  if [[ -f "$target" ]]; then
    echo "skip   $(basename "$target")"
    continue
  fi
  echo "fetch  $(basename "$target")"
  if ! download "${BASE_URL}_${y}_${m}.zip" "$target"; then
    rm -f "$target.part"
    echo "       not available from BTS (yet?)" >&2
    continue
  fi
  unzip -tq "$target" > /dev/null || { echo "error: $target is corrupt; deleted" >&2; rm -f "$target"; exit 1; }
done
