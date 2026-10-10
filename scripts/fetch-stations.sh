#!/usr/bin/env bash
# Downloads the reference data that ties airports to weather stations into
# data/raw/stations/: IEM ASOS station metadata (one GeoJSON per state network)
# and the OurAirports airport list. Small and changes occasionally, so it is
# always refreshed.
#
#   scripts/fetch-stations.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

DEST="$PROJECT_DIR/data/raw/stations"
mkdir -p "$DEST"
# US states plus the territories that appear in BTS data. (Saipan, SPN, has no
# IEM station in any network.)
NETWORKS="AK AL AR AZ CA CO CT DE FL GA HI IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT
          NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY
          PR VI GU AS"

for st in $NETWORKS; do
  net="${st}_ASOS"
  rm -f "$DEST/$net.geojson"
  download "https://mesonet.agron.iastate.edu/geojson/network/$net.geojson" "$DEST/$net.geojson" \
    || echo "warn: no IEM network $net" >&2
  sleep 1   # be polite to IEM
done
echo "Fetched $(ls "$DEST"/*.geojson | wc -l | tr -d ' ') station networks"

rm -f "$DEST/ourairports.csv"
download "https://davidmegginson.github.io/ourairports-data/airports.csv" "$DEST/ourairports.csv"
echo "Fetched $(($(wc -l < "$DEST/ourairports.csv") - 1)) airports from OurAirports"
