#!/usr/bin/env bash
# Configures Grafana on kolcheck over SSH (needs key login and passwordless sudo):
#   - installs the ClickHouse datasource and dashboard provider from grafana/provisioning/
#   - copies grafana/dashboards/*.json to the dashboard folder Grafana watches
#   - gives grafana-server the ClickHouse credentials via a root-only env file
#   - restarts Grafana and reports provisioning errors from its log
# Safe to re-run; re-run after adding or changing dashboards.
#
#   scripts/grafana-provision.sh
#   GRAFANA_SSH=pi@otherhost scripts/grafana-provision.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

GRAFANA_SSH="${GRAFANA_SSH:-pi@kolcheck}"
PROV="$PROJECT_DIR/grafana/provisioning"
[[ -n "$CH_PASSWORD" ]] || { echo "error: no ClickHouse password (clickhouse.properties)" >&2; exit 1; }

remote() { ssh -o BatchMode=yes "$GRAFANA_SSH" "$@"; }

echo "Installing provisioning files on $GRAFANA_SSH"
remote "sudo install -o root -g grafana -m 640 /dev/stdin /etc/grafana/provisioning/datasources/faa-clickhouse.yaml" \
  < "$PROV/datasources/clickhouse.yaml"
remote "sudo install -o root -g grafana -m 640 /dev/stdin /etc/grafana/provisioning/dashboards/faa.yaml" \
  < "$PROV/dashboards/faa.yaml"

remote "sudo install -d -o grafana -g grafana -m 755 /var/lib/grafana/dashboards/faa"
for f in "$PROJECT_DIR"/grafana/dashboards/*.json; do
  [[ -f "$f" ]] || continue
  remote "sudo install -o grafana -g grafana -m 644 /dev/stdin '/var/lib/grafana/dashboards/faa/$(basename "$f")'" < "$f"
  echo "  dashboard $(basename "$f")"
done

# Credentials travel over SSH stdin (never on a command line) into a file only
# root can read; systemd reads it as root and passes it to grafana-server, and
# the datasource YAML references ${CLICKHOUSE_USER} / ${CLICKHOUSE_PASSWORD}.
printf 'CLICKHOUSE_USER=%s\nCLICKHOUSE_PASSWORD=%s\n' "$CH_USER" "$CH_PASSWORD" \
  | remote "sudo install -o root -g root -m 600 /dev/stdin /etc/grafana/faa-clickhouse.env"
remote "sudo install -d /etc/systemd/system/grafana-server.service.d && \
        printf '[Service]\nEnvironmentFile=/etc/grafana/faa-clickhouse.env\n' \
        | sudo tee /etc/systemd/system/grafana-server.service.d/faa-clickhouse.conf > /dev/null"

echo "Restarting Grafana"
since=$(remote "date '+%Y-%m-%d %H:%M:%S'")
remote "sudo systemctl daemon-reload && sudo systemctl restart grafana-server"
for _ in $(seq 30); do
  remote "curl -fs http://localhost:3000/api/health > /dev/null" && break
  sleep 2
done
remote "systemctl is-active grafana-server"

errors=$(remote "sudo journalctl -u grafana-server --since '$since' --no-pager" \
  | grep -E 'logger=provisioning[^ ]* .*level=(error|warn)' || true)
if [[ -n "$errors" ]]; then
  echo "Provisioning problems:" >&2
  echo "$errors" >&2
  exit 1
fi
echo "Grafana provisioned: datasource 'ClickHouse FAA' (uid clickhouse-faa)"
