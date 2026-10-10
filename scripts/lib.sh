# Shared helpers, sourced by the other scripts. Not meant to be run directly.
#
# Connection settings come from CLICKHOUSE_URL / CLICKHOUSE_USER /
# CLICKHOUSE_PASSWORD, falling back to clickhouse.properties, then defaults.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER_JAR="$PROJECT_DIR/target/clickhouse-faadata-demo-0.1.0-SNAPSHOT-all.jar"

prop() {
  [[ -f "$PROJECT_DIR/clickhouse.properties" ]] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$PROJECT_DIR/clickhouse.properties" | tail -1
}

CH_URL="${CLICKHOUSE_URL:-$(prop clickhouse.url)}"; CH_URL="${CH_URL:-http://xraytunnel:8123}"
CH_USER="${CLICKHOUSE_USER:-$(prop clickhouse.user)}"; CH_USER="${CH_USER:-default}"
CH_PASSWORD="${CLICKHOUSE_PASSWORD:-$(prop clickhouse.password)}"

# ch_query SQL [curl args...]: run one statement over HTTP, print the result.
# The password goes in a header, not the URL, so it never shows up in logs.
ch_query() {
  local sql="$1"; shift
  curl -sS --fail-with-body "$CH_URL/" \
    -H "X-ClickHouse-User: $CH_USER" \
    -H "X-ClickHouse-Key: $CH_PASSWORD" \
    --data-binary "$sql" "$@"
}

# ch_insert "INSERT INTO t FORMAT X" < data: stream stdin as the insert's data.
ch_insert() {
  local q
  q=$(python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1")
  curl -sS --fail-with-body "$CH_URL/?query=$q" \
    -H "X-ClickHouse-User: $CH_USER" \
    -H "X-ClickHouse-Key: $CH_PASSWORD" \
    --data-binary @-
}

ch_check_connection() {
  local version
  version=$(ch_query 'SELECT version()') || { echo "error: cannot connect to $CH_URL as $CH_USER: $version" >&2; exit 1; }
  echo "ClickHouse $version at $CH_URL as $CH_USER"
}

# Builds the Java loader if it isn't there yet.
ensure_loader() {
  if [[ ! -f "$LOADER_JAR" ]]; then
    echo "Building loader..."
    (cd "$PROJECT_DIR" && mvn -q -B package -DskipTests)
  fi
}

# Polite downloader: retries, resumes, and only renames into place when complete.
download() {
  local url="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  curl -fsSL --retry 5 --retry-delay 10 -C - -o "$target.part" "$url" && mv "$target.part" "$target"
}

# month_range 2024-11 2025-02 -> 2024-11 2024-12 2025-01 2025-02
month_range() {
  local y=$((10#${1%-*})) m=$((10#${1#*-})) ey=$((10#${2%-*})) em=$((10#${2#*-}))
  while (( y * 12 + m <= ey * 12 + em )); do
    printf '%04d-%02d\n' "$y" "$m"
    (( m == 12 )) && { m=1; y=$((y + 1)); } || m=$((m + 1))
  done
}
