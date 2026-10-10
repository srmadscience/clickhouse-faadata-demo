#!/usr/bin/env bash
# Records or verifies SHA-256 checksums of the raw data so everyone (and the
# server) can prove they loaded exactly the same files.
#   scripts/checksums.sh update   rewrite data/manifest.sha256 (commit it)
#   scripts/checksums.sh verify   check local files against the manifest
set -euo pipefail
cd "$(dirname "$0")/../data"

case "${1:-verify}" in
  update) find raw -type f ! -name '.gitkeep' ! -name '*.part' | sort | xargs shasum -a 256 > manifest.sha256
          echo "Wrote $(wc -l < manifest.sha256 | tr -d ' ') entries to data/manifest.sha256" ;;
  verify) shasum -a 256 -c manifest.sha256 ;;
  *)      echo "usage: $0 update|verify" >&2; exit 1 ;;
esac
