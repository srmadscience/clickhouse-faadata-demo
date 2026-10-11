#!/usr/bin/env bash
# Copyright 2026 David Rolfe
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Downloads BTS on-time performance files (one zip per month) into data/raw/flights/.
# Each month comes from the project's mirror (GitHub Releases, see lib.sh) if
# it is there, otherwise from BTS. Already-downloaded months are skipped, so it
# is safe to re-run.
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
MIRROR=$(mirror_assets data-flights)

for ym in $(month_range "$1" "$2"); do
  y=${ym%-*}; m=$((10#${ym#*-}))
  name="ontime_${y}_$(printf %02d "$m").zip"
  target="$DEST/$name"
  if [[ -f "$target" ]]; then
    echo "skip   $name"
    continue
  fi
  if mirror_fetch "$MIRROR" "$name" "$target"; then
    echo "fetch  $name  (mirror)"
  elif download "${BASE_URL}_${y}_${m}.zip" "$target"; then
    echo "fetch  $name  (BTS)"
  else
    rm -f "$target.part"
    echo "       $name: not available from BTS (yet?)" >&2
    continue
  fi
  unzip -tq "$target" > /dev/null || { echo "error: $target is corrupt; deleted" >&2; rm -f "$target"; exit 1; }
done
