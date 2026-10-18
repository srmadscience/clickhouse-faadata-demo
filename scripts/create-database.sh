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

# Creates the faa database (and any tables) by running sql/*.sql against
# ClickHouse in file-name order. Every statement uses IF NOT EXISTS, so it is
# safe to re-run. The statements run in the Java loader, as one trace when
# OpenTelemetry is set up, with a span per file.
#
#   scripts/create-database.sh            run everything in sql/
#   scripts/create-database.sh FILE...    run only the given files
#   DRY_RUN=1 scripts/create-database.sh  print the statements, run nothing
#
# Connection settings: see scripts/lib.sh.
# Statements must end with ';' at the end of a line.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$PROJECT_DIR"

files=("$@")
[[ ${#files[@]} -gt 0 ]] || files=(sql/*.sql)

generate() {
  local file stmt line
  for file in "${files[@]}"; do
    sql_span "sql file" "faa.file=$file"
    sql_log "== $file"
    stmt=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^[[:space:]]*(--|$) ]] && continue
      stmt+="$line"$'\n'
      if [[ "$line" =~ \;[[:space:]]*$ ]]; then
        sql_log "   ${stmt%%$'\n'*}"
        sql_stmt "$stmt"
        stmt=""
      fi
    done < "$file"
    if [[ -n "${stmt//[[:space:]]/}" ]]; then
      echo "error: $file has a statement without a terminating ';'" >&2
      exit 1
    fi
  done
  [[ -n "${DRY_RUN:-}" ]] && return
  sql_span
  sql_log "Tables in faa:"
  sql_stmt "SELECT name, engine, total_rows FROM system.tables WHERE database = 'faa' ORDER BY name FORMAT PrettyCompact"
}

if [[ -n "${DRY_RUN:-}" ]]; then
  sql_stmt() { printf '%s\n\n' "$1"; }
  sql_span() { :; }
  sql_log() { :; }
  generate
else
  ch_check_connection
  ensure_loader
  generate | run_sql_script create-database
fi
