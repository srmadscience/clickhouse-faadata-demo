#!/usr/bin/env bash
# Downloads the FAA aircraft registry (ReleasableAircraft.zip, ~70 MB, updated
# daily) into data/raw/registry/ReleasableAircraft_YYYYMMDD.zip. Skipped if
# today's copy exists; older copies are kept so earlier loads can be redone.
#
#   scripts/fetch-registry.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

URL="https://registry.faa.gov/database/ReleasableAircraft.zip"
target="$PROJECT_DIR/data/raw/registry/ReleasableAircraft_$(date -u +%Y%m%d).zip"
if [[ -f "$target" ]]; then
  echo "skip   $(basename "$target")"
  exit 0
fi

echo "fetch  $(basename "$target")"
# registry.faa.gov's CDN refuses curl's default User-Agent with a 403.
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36"
mkdir -p "$(dirname "$target")"
curl -fsSL --retry 5 --retry-delay 10 -A "$UA" -o "$target.part" "$URL"
unzip -tq "$target.part" > /dev/null || { echo "error: download is not a valid zip" >&2; rm -f "$target.part"; exit 1; }
mv "$target.part" "$target"
