#!/usr/bin/env bash
# Creates (or updates) the ClickHouse datasource on Grafana via its HTTP API,
# as an alternative to copying grafana/provisioning/ onto the Grafana host.
#   GRAFANA_TOKEN=glsa_... CLICKHOUSE_PASSWORD=... scripts/grafana-datasource.sh
# The token is a Grafana service account token with the Admin role.
# Requires the grafana-clickhouse-datasource plugin to be installed on Grafana.
set -euo pipefail
GRAFANA_URL="${GRAFANA_URL:-http://kolcheck:3000}"
: "${GRAFANA_TOKEN:?set GRAFANA_TOKEN}"
: "${CLICKHOUSE_PASSWORD:?set CLICKHOUSE_PASSWORD}"
UID_="clickhouse-faa"

body=$(cat <<JSON
{
  "name": "ClickHouse FAA",
  "uid": "$UID_",
  "type": "grafana-clickhouse-datasource",
  "access": "proxy",
  "isDefault": true,
  "jsonData": {
    "host": "${CLICKHOUSE_HOST:-xraytunnel}",
    "port": 9000,
    "protocol": "native",
    "username": "${CLICKHOUSE_USER:-default}",
    "defaultDatabase": "faa"
  },
  "secureJsonData": { "password": "$CLICKHOUSE_PASSWORD" }
}
JSON
)

auth=(-H "Authorization: Bearer $GRAFANA_TOKEN" -H "Content-Type: application/json")
if curl -fs "${auth[@]}" "$GRAFANA_URL/api/datasources/uid/$UID_" > /dev/null; then
  curl -fsS -X PUT "${auth[@]}" -d "$body" "$GRAFANA_URL/api/datasources/uid/$UID_"
else
  curl -fsS -X POST "${auth[@]}" -d "$body" "$GRAFANA_URL/api/datasources"
fi
echo
