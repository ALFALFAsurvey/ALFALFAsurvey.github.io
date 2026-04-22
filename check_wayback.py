"""
check_wayback.py
================
Checks whether each non-~a2010 NAIC URL in aweb/ and rwebhtml/ has a
snapshot in the Wayback Machine, using the Availability API.

Output: a tab-separated report saved to wayback_results.tsv
  url | available | snapshot_url | snapshot_timestamp

Usage:
  pip install requests
  python check_wayback.py              # scan aweb/ and rwebhtml/ automatically
  python check_wayback.py urls.txt     # check URLs listed one-per-line in a file
  python check_wayback.py http://...   # check a single URL directly
"""

import sys
import time
import re
import requests
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
OUTPUT    = REPO_ROOT / "wayback_results.tsv"

# ─── Collect URLs from the repo ───────────────────────────────────────────────

URL_RE   = re.compile(r'https?://[^\s"\'<>]+naic[^\s"\'<>]+', re.IGNORECASE)
A2010_RE = re.compile(r'(?:~|%7[Ee])a2010', re.IGNORECASE)

def normalize(url: str) -> str:
    """Strip trailing slash for consistent deduplication."""
    return url.rstrip("/")

def collect_urls_from_repo() -> list[str]:
    urls = set()
    for d in ("aweb", "rwebhtml"):
        search_dir = REPO_ROOT / d
        if not search_dir.exists():
            continue
        for ext in ("*.html", "*.htm"):
            for f in search_dir.rglob(ext):
                text = f.read_text(encoding="utf-8", errors="replace")
                for m in URL_RE.finditer(text):
                    url = normalize(m.group(0))
                    if not A2010_RE.search(url) and not url.startswith("http://www.naic.edu/$"):
                        urls.add(url)
    # Sort shortest first so root URLs are checked before their subpages
    return sorted(urls, key=len)

# ─── Wayback check ────────────────────────────────────────────────────────────

AVAILABILITY_API = "https://archive.org/wayback/available"
CDX_API          = "http://web.archive.org/cdx/search/cdx"

def _query_availability(url: str) -> tuple[bool, str, str]:
    r = requests.get(AVAILABILITY_API, params={"url": url}, timeout=10)
    r.raise_for_status()
    snapshot = r.json().get("archived_snapshots", {}).get("closest", {})
    if snapshot.get("available"):
        return True, snapshot.get("url", ""), snapshot.get("timestamp", "")
    return False, "", ""

def _strip_default_port(url: str) -> str:
    """Remove explicit default ports (:80 for http, :443 for https)."""
    url = re.sub(r'^(https?://)([^/:]+):80(/)', r'\1\2\3', url)
    url = re.sub(r'^(https://)([^/:]+):443(/)', r'\1\2\3', url)
    return url

def _query_cdx(url: str) -> tuple[bool, str, str]:
    r = requests.get(CDX_API, params={
        "url": url, "output": "json", "limit": 1,
        "fl": "timestamp,original", "filter": "statuscode:200",
    }, timeout=10)
    r.raise_for_status()
    rows = r.json()
    if len(rows) > 1:  # first row is the field header
        timestamp, original = rows[1]
        original = _strip_default_port(original)
        snapshot_url = f"https://web.archive.org/web/{timestamp}/{original}"
        return True, snapshot_url, timestamp
    return False, "", ""

def check_wayback(url: str) -> tuple[bool, str, str]:
    """Try Availability API first; fall back to CDX API if NO; retry both with trailing slash."""
    try:
        # 1. Availability API (fast)
        result = _query_availability(url)
        if result[0]:
            return result
        # 2. CDX API (more thorough)
        time.sleep(0.2)
        result = _query_cdx(url)
        if result[0]:
            return result
        # 3. Retry both with trailing slash for directory-style URLs
        if not url.endswith("/"):
            time.sleep(0.2)
            result = _query_availability(url + "/")
            if result[0]:
                return result
            time.sleep(0.2)
            result = _query_cdx(url + "/")
            if result[0]:
                return result
        return False, "", ""
    except Exception as e:
        return False, "", f"ERROR: {e}"

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]

    if not args:
        urls = collect_urls_from_repo()
    elif len(args) == 1 and args[0].startswith("http"):
        urls = [args[0]]
    else:
        # Treat argument as a file of URLs, one per line
        path = Path(args[0])
        urls = [l.strip() for l in path.read_text().splitlines() if l.strip() and not l.startswith("#")]

    print(f"Checking {len(urls)} URLs against Wayback Machine...\n")

    results = []
    failed_prefixes: list[str] = []

    for i, url in enumerate(urls, 1):
        # Skip if a shorter failed URL is a prefix of this one
        prefix = url.rstrip("/") + "/"
        skipped_by = next((p for p in failed_prefixes if prefix.startswith(p)), None)
        if skipped_by:
            print(f"[{i:3}/{len(urls)}] SKIP {url}")
            print(f"           (parent {skipped_by} not in Wayback)")
            results.append((url, "SKIP", "", ""))
            continue

        available, snapshot_url, timestamp = check_wayback(url)
        status = "YES" if available else "NO"
        print(f"[{i:3}/{len(urls)}] {status}  {url}")
        if available:
            print(f"           {snapshot_url}")
        else:
            # Only use as a prefix blocker if there's a real path (not just a bare domain)
            if urlparse(url).path.strip("/"):
                failed_prefixes.append(url.rstrip("/") + "/")
        results.append((url, status, snapshot_url, timestamp))
        time.sleep(0.2)  # be polite to the API

    with OUTPUT.open("w", encoding="utf-8") as f:
        f.write("url\tavailable\tsnapshot_url\ttimestamp\n")
        for row in results:
            f.write("\t".join(row) + "\n")

    available_count = sum(1 for _, s, _, _ in results if s == "YES")
    skipped_count   = sum(1 for _, s, _, _ in results if s == "SKIP")
    print(f"\nResults: {available_count}/{len(urls)} URLs found in Wayback Machine ({skipped_count} skipped)")
    print(f"Saved to {OUTPUT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
