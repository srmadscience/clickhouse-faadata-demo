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

# Rebuilds everything from scratch, in order: schema, flights and their
# per-aircraft summary, stations, weather, flights joined to weather, aircraft registry.
# Every step is idempotent, so this is also the way to extend the date range.
#
#   scripts/reproduce.sh 2025-01 2025-12
set -euo pipefail
cd "$(dirname "$0")"

[[ $# -eq 2 ]] || { echo "usage: $0 FROM_YYYY-MM TO_YYYY-MM" >&2; exit 1; }

./create-database.sh
./fetch-flights.sh "$1" "$2"
./load-flights.sh
./build-tail-day.sh
./fetch-stations.sh
./load-stations.sh
./fetch-weather.sh "${1%-*}" "${2%-*}"
./load-weather.sh
./build-flight-weather.sh
./fetch-registry.sh
./load-registry.sh
