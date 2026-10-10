"""Converts IEM network GeoJSON files to CSV rows for faa.stations.

Usage: python3 -I stations_to_csv.py FILE.geojson... > stations.csv
"""
import csv
import json
import sys

out = csv.writer(sys.stdout)
for path in sys.argv[1:]:
    with open(path) as f:
        for feature in json.load(f)["features"]:
            p = feature["properties"]
            lon, lat = feature["geometry"]["coordinates"][:2]
            out.writerow([
                feature["id"], p.get("network", ""), p.get("sname", ""), p.get("state") or "",
                p.get("country") or "", lat, lon,
                "" if p.get("elevation") is None else p["elevation"],
                p.get("tzname") or "", p.get("archive_begin") or "",
            ])
