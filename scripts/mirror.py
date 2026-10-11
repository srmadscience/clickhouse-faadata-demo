"""Lists the files of one GitHub release, one per line: name, SHA-256 and
download URL, tab-separated. Used by mirror_assets in lib.sh. Prints nothing
if the release does not exist. Uses $GITHUB_TOKEN if set (higher rate limit).

    python3 -I scripts/mirror.py OWNER/REPO TAG
"""
import json
import os
import sys
import urllib.error
import urllib.request

repo, tag = sys.argv[1:3]
api = f"https://api.github.com/repos/{repo}/releases"


def get(url):
    headers = {"Accept": "application/vnd.github+json"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
        return json.load(r)


try:
    release = get(f"{api}/tags/{tag}")
    page = 1
    while True:
        assets = get(f"{api}/{release['id']}/assets?per_page=100&page={page}")
        for a in assets:
            digest = a.get("digest") or ""
            if a.get("state") == "uploaded" and digest.startswith("sha256:"):
                print(a["name"], digest[len("sha256:"):], a["browser_download_url"], sep="\t")
        if len(assets) < 100:
            break
        page += 1
except urllib.error.HTTPError as e:
    if e.code != 404:
        print(f"warn: cannot list release {tag} of {repo}: HTTP {e.code}", file=sys.stderr)
except OSError as e:
    print(f"warn: cannot list release {tag} of {repo}: {e}", file=sys.stderr)
