"""
check_wayback.py
================
1. Scan all HTML files in the repo for external http(s) links.
2. Check each link for liveness (HEAD → GET fallback).
3. For dead links, check the Wayback Machine for an archived snapshot.

Output: tab-separated report saved to wayback_results.tsv
  url | live | wayback | wayback_url | wayback_timestamp

Columns:
  live      LIVE / DEAD / ERROR:<msg>
  wayback   YES / NO / SKIP / N/A (N/A when live=LIVE, SKIP when parent
            path already failed)

Usage:
  python check_wayback.py              # full scan of repo
  python check_wayback.py urls.txt     # check URLs listed one-per-line
  python check_wayback.py http://...   # check a single URL

Flags (append after the positional arg, or before it for repo-scan mode):
  --naic-only        only check naic.edu URLs
  --skip-live-check  skip HTTP liveness check; treat all URLs as dead
                     (goes straight to Wayback — useful when you know a
                     domain is down and just want Wayback coverage)
  --recheck-errors   re-check rows from an existing TSV that have
                     live=ERROR or wayback=ERROR (reads wayback_results.tsv)
  --recheck-wayback  re-query Wayback for all DEAD+YES rows to get the most
                     recent snapshot (useful after fixing the CDX sort order)
"""

import sys
import time
import re
import threading
import concurrent.futures
from collections import deque
import requests
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT        = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
OUTPUT           = REPO_ROOT / "wayback_results.tsv"
FALLBACKS_FILE   = REPO_ROOT / "wayback_fallbacks.txt"

SCAN_DIRS  = ("aweb", "rwebhtml")   # sub-dirs to scan (plus root *.html)

# ─── URL collection ──────────────────────────────────────────────────────────

ATTR_URL_RE = re.compile(                          # URLs in href/src/action attributes
    r'(?:href|src|action)=["\'](\s*https?://[^"\']+)["\']', re.IGNORECASE
)
URL_RE     = re.compile(r'https?://[^\s"\'<>]+', re.IGNORECASE)   # URLs in text
NAIC_RE    = re.compile(r'naic', re.IGNORECASE)
A2010_RE   = re.compile(r'(?:~|%7[Ee])a2010', re.IGNORECASE)

# Domains we know are stable — skip liveness + Wayback unless --naic-only not set
# (we still collect them for the record but mark them as presumed live)
SKIP_DOMAINS = {
    "github.com", "arxiv.org", "ui.adsabs.harvard.edu",
    "drive.google.com", "fonts.googleapis.com", "fonts.gstatic.com",
    "alfalfasurvey.github.io",
    "skyview.gsfc.nasa.gov",   # CGI queries take >12s; site is confirmed live
}


def normalize(url: str) -> str:
    """Strip fragment, trailing slash, and stray punctuation that the regex
    may capture when a URL appears in running text (e.g. 'see http://x.com.')."""
    url = url.split("#")[0]
    url = url.rstrip("/.,;:!?)")   # stray sentence punctuation, never part of a URL
    return url


def collect_urls_from_repo(naic_only: bool = False) -> list[str]:
    urls: set[str] = set()

    # Root-level HTML files
    for f in REPO_ROOT.glob("*.html"):
        _harvest(f, urls, naic_only)

    # Sub-directories
    for d in SCAN_DIRS:
        search_dir = REPO_ROOT / d
        if not search_dir.exists():
            continue
        for ext in ("*.html", "*.htm"):
            for f in search_dir.rglob(ext):
                _harvest(f, urls, naic_only)

    return sorted(urls, key=len)


def _harvest(path: Path, urls: set[str], naic_only: bool) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")

    # Attribute URLs are authoritative: capture the full value (may contain literal
    # spaces in query params like &dec=  2.15) and percent-encode those spaces.
    attr_urls: list[str] = [
        normalize(m.group(1).strip().replace(" ", "%20"))
        for m in ATTR_URL_RE.finditer(text)
    ]

    # Text URLs stop at whitespace, so a URL like ...&dec=  2.15 becomes ...&dec=
    # (truncated). We add text URLs only when they aren't a truncated prefix of an
    # attribute URL already captured above.
    attr_set = set(attr_urls)
    text_urls: list[str] = [
        normalize(m.group(0))
        for m in URL_RE.finditer(text)
        if not any(a.startswith(m.group(0).rstrip("/.,;:!?)")) for a in attr_set)
    ]

    def _add(url: str) -> None:
        if not url.startswith("http"):
            return
        if A2010_RE.search(url):
            return
        if naic_only and not NAIC_RE.search(url):
            return
        parsed = urlparse(url)
        if parsed.netloc in SKIP_DOMAINS:
            return
        urls.add(url)

    for url in attr_urls:
        _add(url)
    for url in text_urls:
        _add(url)


# ─── Liveness check ──────────────────────────────────────────────────────────

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (compatible; ALFALFAsurvey link-checker; "
        "+https://alfalfasurvey.github.io/)"
    )
}
LIVE_TIMEOUT  = 12
LIVE_RETRIES  = 2
LIVE_WORKERS  = 20   # concurrent threads for HEAD requests

# Dead-domain cache: once we know a domain is unreachable at the network level
# (DNS gone, SSL repurposed, connection refused), all URLs on that domain are
# immediately returned as DEAD without making another HTTP request.
_dead_domains: set[str] = set()
_dead_domains_lock = threading.Lock()


def _domain(url: str) -> str:
    return urlparse(url).netloc


def _mark_dead(url: str) -> None:
    with _dead_domains_lock:
        _dead_domains.add(_domain(url))


def _is_domain_dead(url: str) -> bool:
    with _dead_domains_lock:
        return _domain(url) in _dead_domains


def check_live(url: str) -> str:
    """Return 'LIVE', 'DEAD', or 'ERROR:<msg>'.

    Domain-level failures (DNS, SSL repurpose, connection refused) are cached
    so subsequent URLs on the same domain are instantly returned as DEAD.
    """
    if _is_domain_dead(url):
        return "DEAD"

    for attempt in range(LIVE_RETRIES):
        try:
            r = requests.head(
                url, timeout=LIVE_TIMEOUT, allow_redirects=True,
                headers=HEADERS,
            )
            if r.status_code < 400:
                return "LIVE"
            # Some servers don't support HEAD — fall back to GET
            if r.status_code in (405, 501):
                rg = requests.get(
                    url, timeout=LIVE_TIMEOUT, allow_redirects=True,
                    headers=HEADERS, stream=True,
                )
                rg.close()
                return "LIVE" if rg.status_code < 400 else "DEAD"
            return "DEAD"
        except requests.exceptions.Timeout:
            if attempt < LIVE_RETRIES - 1:
                time.sleep(1)
                continue
            # Some servers (e.g. CGI scripts) silently drop HEAD and just hang.
            # Try a streaming GET before giving up.
            try:
                rg = requests.get(
                    url, timeout=LIVE_TIMEOUT, allow_redirects=True,
                    headers=HEADERS, stream=True,
                )
                rg.close()
                return "LIVE" if rg.status_code < 400 else "DEAD"
            except Exception:
                pass
            return "ERROR:timeout"
        except requests.exceptions.SSLError:
            # SSL error after redirect → domain was repurposed; mark whole domain dead
            _mark_dead(url)
            return "DEAD"
        except requests.exceptions.ConnectionError as e:
            err = str(e)
            if "Name or service not known" in err or "nodename nor servname" in err:
                _mark_dead(url)   # DNS failure → domain is gone
                return "DEAD"
            if "Connection refused" in err or "Max retries exceeded" in err:
                _mark_dead(url)
                return "DEAD"
            return f"ERROR:conn:{err:.60}"
        except Exception as e:
            return f"ERROR:{e!s:.80}"
    return "ERROR:timeout"


# ─── Wayback Machine check ───────────────────────────────────────────────────

AVAILABILITY_API        = "https://archive.org/wayback/available"
CDX_API                 = "https://web.archive.org/cdx/search/cdx"   # MUST be https://
WAYBACK_TIMEOUT         = 15   # normal runs: API responds in 5-7s on a slow day
WAYBACK_TIMEOUT_RECHECK = 30   # recheck runs: known-slow URLs get more time
WAYBACK_WORKERS         = 3    # conservative parallelism to stay polite to archive.org
WAYBACK_RATE_LIMIT      = 60   # max API calls per 60-second window

# Active timeout — bumped to WAYBACK_TIMEOUT_RECHECK in --recheck-errors mode
_active_wayback_timeout = WAYBACK_TIMEOUT

# ─── Rate limiter ─────────────────────────────────────────────────────────────
# Sliding-window counter: tracks timestamps of the last WAYBACK_RATE_LIMIT calls.
# Sleep outside the lock so workers aren't unnecessarily serialized.

_api_call_times: deque[float] = deque()
_rate_lock = threading.Lock()


def _rate_limit() -> None:
    """Block if necessary to stay under WAYBACK_RATE_LIMIT calls per minute."""
    while True:
        with _rate_lock:
            now = time.time()
            cutoff = now - 60.0
            while _api_call_times and _api_call_times[0] < cutoff:
                _api_call_times.popleft()
            if len(_api_call_times) < WAYBACK_RATE_LIMIT:
                _api_call_times.append(now)
                return
            sleep_until = _api_call_times[0] + 60.1  # just past the oldest call's window
        time.sleep(max(0.0, sleep_until - time.time()))


def _strip_default_port(url: str) -> str:
    url = re.sub(r'^(https?://)([^/:]+):80(/)', r'\1\2\3', url)
    url = re.sub(r'^(https://)([^/:]+):443(/)', r'\1\2\3', url)
    return url


def _query_availability(url: str) -> tuple[bool, str, str]:
    _rate_limit()
    r = requests.get(
        AVAILABILITY_API, params={"url": url, "timestamp": "20260101000000"},
        timeout=_active_wayback_timeout, headers=HEADERS,
    )
    r.raise_for_status()
    snapshot = r.json().get("archived_snapshots", {}).get("closest", {})
    if snapshot.get("available"):
        return True, _strip_default_port(snapshot.get("url", "")), snapshot.get("timestamp", "")
    return False, "", ""


def _query_cdx(url: str) -> tuple[bool, str, str]:
    _rate_limit()
    r = requests.get(
        CDX_API,
        params={
            "url": url, "output": "json", "limit": 1,
            "fl": "timestamp,original", "filter": "statuscode:200",
            "sort": "reverse",
        },
        timeout=_active_wayback_timeout, headers=HEADERS,
    )
    r.raise_for_status()
    rows = r.json()
    if len(rows) > 1:
        timestamp, original = rows[1]
        original = _strip_default_port(original)
        snapshot_url = f"https://web.archive.org/web/{timestamp}/{original}"
        return True, snapshot_url, timestamp
    return False, "", ""


def _has_extension(url: str) -> bool:
    """True if the last path component looks like a file (has a dot-extension)."""
    last = urlparse(url).path.rstrip("/").rsplit("/", 1)[-1]
    return "." in last


def _check_one_url_in_wayback(url: str) -> tuple[bool, str, str]:
    """Try Availability API, then CDX. Also tries with trailing slash but only
    for directory-style URLs (no file extension) — file URLs never redirect to
    a directory, so the slash variant would always be wasted calls."""
    result = _query_availability(url)
    if result[0]:
        return result
    result = _query_cdx(url)
    if result[0]:
        return result
    # Trailing-slash retry only makes sense for directory-style paths
    if not url.endswith("/") and not _has_extension(url):
        result = _query_availability(url + "/")
        if result[0]:
            return result
        result = _query_cdx(url + "/")
        if result[0]:
            return result
    return False, "", ""


def _dot_old_variant(url: str) -> str | None:
    """Return the .old/ sibling URL for naic.edu /vscience/schedule/ files, else None.
    This is the only known site that used a .old/ convention."""
    p = urlparse(url)
    if "naic.edu" not in p.netloc:
        return None
    if "/schedule/" not in p.path:
        return None
    parent, filename = p.path.rstrip("/").rsplit("/", 1)
    if not filename:
        return None
    return p._replace(path=parent + "/.old/" + filename).geturl()


def check_wayback(url: str) -> tuple[str, str, str]:
    """Return (wayback_status, snapshot_url, timestamp).
    wayback_status: 'YES' | 'NO' | 'ERROR:<msg>'
    """
    for attempt in range(2):
        try:
            found, snap_url, ts = _check_one_url_in_wayback(url)
            if found:
                return "YES", snap_url, ts
            alt = _dot_old_variant(url)
            if alt:
                found, snap_url, ts = _check_one_url_in_wayback(alt)
                if found:
                    return "YES", snap_url, ts
            return "NO", "", ""
        except requests.exceptions.Timeout:
            return "ERROR:timeout", "", ""
        except requests.exceptions.ConnectionError:
            if attempt == 0:
                time.sleep(3)
                continue
            return "ERROR:conn", "", ""
        except Exception as e:
            return f"ERROR:{e!s:.80}", "", ""
    return "ERROR:conn", "", ""


# ─── TSV helpers ─────────────────────────────────────────────────────────────

def _read_tsv(tsv_path: Path) -> list[tuple[str, ...]]:
    rows = []
    for line in tsv_path.read_text(encoding="utf-8").splitlines()[1:]:
        parts = (line.split("\t") + ["", "", "", ""])[:5]
        rows.append(tuple(parts))
    return rows


def load_prior_results(tsv_path: Path) -> dict[str, tuple[str, str, str, str]]:
    """Load completed (non-error) rows from an existing TSV so they can be skipped."""
    prior: dict[str, tuple[str, str, str, str]] = {}
    for url, live, wayback, wb_url, ts in _read_tsv(tsv_path):
        if not live.startswith("ERROR") and not wayback.startswith("ERROR"):
            prior[url] = (live, wayback, wb_url, ts)
    return prior


def load_error_urls(tsv_path: Path) -> list[str]:
    """Return URLs whose live or wayback column starts with 'ERROR'."""
    return [
        url for url, live, wayback, *_ in _read_tsv(tsv_path)
        if live.startswith("ERROR") or wayback.startswith("ERROR")
    ]


def load_wayback_yes_urls(tsv_path: Path) -> tuple[list[str], dict[str, tuple[str, str]]]:
    """Return (urls_to_recheck, fallback_map) for all DEAD+YES rows.

    fallback_map: {url: (old_wayback_url, old_timestamp)} — used if the
    re-query errors so we fall back to the previously found snapshot.
    Deduplicates: if a URL appears multiple times (e.g. from a mid-run crash
    followed by a retry), only the last occurrence is kept.
    """
    fallback: dict[str, tuple[str, str]] = {}
    for url, live, wayback, wb_url, ts in _read_tsv(tsv_path):
        if live == "DEAD" and wayback == "YES":
            fallback[url] = (wb_url, ts)   # last occurrence wins
    urls = list(fallback.keys())
    return urls, fallback


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]

    naic_only        = "--naic-only" in args
    skip_live_check  = "--skip-live-check" in args
    recheck_errors   = "--recheck-errors" in args
    recheck_wayback  = "--recheck-wayback" in args
    args = [a for a in args if not a.startswith("--")]

    # ── Load prior results before opening the output file for writing ─────────
    # Both resume mode and --recheck-errors write prior (non-error) rows first
    # so the output file is always complete and valid, even mid-run.
    prior: dict[str, tuple[str, str, str, str]] = {}
    if OUTPUT.exists():
        prior = load_prior_results(OUTPUT)

    # Fallback map for --recheck-wayback: old snapshot to use if re-query errors
    _wayback_fallback: dict[str, tuple[str, str]] = {}

    if recheck_errors:
        if not OUTPUT.exists():
            print(f"No existing {OUTPUT.name} to recheck.")
            sys.exit(1)
        global _active_wayback_timeout
        _active_wayback_timeout = WAYBACK_TIMEOUT_RECHECK
        urls = load_error_urls(OUTPUT)
        print(f"Rechecking {len(urls)} URLs that previously errored "
              f"(Wayback timeout: {WAYBACK_TIMEOUT_RECHECK}s)...\n")
    elif recheck_wayback:
        if not OUTPUT.exists():
            print(f"No existing {OUTPUT.name} to recheck.")
            sys.exit(1)
        all_yes_urls, _wayback_fallback = load_wayback_yes_urls(OUTPUT)
        if FALLBACKS_FILE.exists():
            fallback_set = {
                l.strip() for l in FALLBACKS_FILE.read_text().splitlines()
                if l.strip() and not l.startswith("#")
            }
            urls = [u for u in all_yes_urls if u in fallback_set]
            print(f"Re-querying {len(urls)} fallback URLs from {FALLBACKS_FILE.name} "
                  f"(will keep old snapshot on error)...\n")
        else:
            urls = all_yes_urls
            print(f"Re-querying Wayback for {len(urls)} DEAD+YES URLs "
                  f"(will keep old snapshot on error)...\n")
        # Intentionally keep DEAD+YES rows in prior so they are written to the
        # output file at the start of the run. If the script dies mid-run, those
        # rows are still present in the TSV. Phase 2 appends updated rows for
        # each URL as it completes; load_prior_results uses a dict so the last
        # occurrence (the updated one) wins on the next read. After a successful
        # run the TSV is deduplicated and rewritten atomically.
    elif not args:
        urls = collect_urls_from_repo(naic_only=naic_only)
        mode = "NAIC-only" if naic_only else "all external"
        print(f"Found {len(urls)} unique {mode} URLs across repo HTML files.\n")
        if prior:
            before = len(urls)
            urls = [u for u in urls if u not in prior]
            print(f"Resuming: {len(prior)} already done, "
                  f"{before - len(prior)} skipped, {len(urls)} remaining.\n")
    elif all(a.startswith("http") for a in args):
        urls = [normalize(a) for a in args]
    else:
        path = Path(args[0])
        urls = [
            normalize(l.strip())
            for l in path.read_text().splitlines()
            if l.strip() and not l.startswith("#")
        ]

    n = len(urls)
    print(f"Checking {n} URLs...\n")

    print_lock = threading.Lock()

    # ── Open output file; write prior results first so file is valid on crash ──
    out = OUTPUT.open("w", encoding="utf-8")
    out.write("url\tlive\twayback\twayback_url\twayback_timestamp\n")
    for url, (live, wayback, wb_url, ts) in prior.items():
        out.write(f"{url}\t{live}\t{wayback}\t{wb_url}\t{ts}\n")
    out.flush()

    # summary counters (prior + new)
    tally = {
        "live": sum(1 for v in prior.values() if v[0] == "LIVE"),
        "dead": sum(1 for v in prior.values() if v[0] == "DEAD"),
        "live_err": 0,
        "wb_yes":  sum(1 for v in prior.values() if v[1] == "YES"),
        "wb_no":   sum(1 for v in prior.values() if v[1] == "NO"),
        "wb_err":  0,
    }

    def _write(row: tuple[str, str, str, str, str]) -> None:
        out.write("\t".join(row) + "\n")
        out.flush()

    # ── Phase 1: parallel liveness checks ────────────────────────────────────
    live_results: dict[str, str] = {}

    if not n:
        print("Nothing new to check.")
    elif recheck_wayback or skip_live_check:
        live_results = {u: "DEAD" for u in urls}
        if recheck_wayback:
            print(f"Skipping liveness check — all {n} already known DEAD.\n")
        else:
            print(f"Skipping liveness check — treating all {n} as DEAD.\n")
    else:
        workers = min(LIVE_WORKERS, n)
        counts = {"done": 0, "live": 0, "dead": 0, "error": 0}

        def _progress1() -> str:
            return (
                f"  [{counts['done']:{len(str(n))}}/{n}  "
                f"live:{counts['live']}  dead:{counts['dead']}  "
                f"error:{counts['error']}]          "
            )

        def _check_one(url: str) -> tuple[str, str]:
            status = check_live(url)
            with print_lock:
                counts["done"] += 1
                if status == "LIVE":
                    counts["live"] += 1
                    print(f"\r  LIVE   {url}")
                elif status.startswith("ERROR"):
                    counts["error"] += 1
                    print(f"\r  {status[:60]}  {url}")
                else:
                    counts["dead"] += 1
                print(_progress1(), end="\r", flush=True)
            return url, status

        print(f"Phase 1 — liveness checks ({workers} threads)...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
            for url, status in ex.map(_check_one, urls):
                live_results[url] = status
                # Write LIVE and live-ERROR rows immediately — they need no Wayback check
                if status == "LIVE":
                    tally["live"] += 1
                    _write((url, status, "N/A", "", ""))
                elif status.startswith("ERROR"):
                    tally["live_err"] += 1
                    _write((url, status, "SKIP", "", ""))
        print(f"\r  done: {n}  live:{counts['live']}  "
              f"dead:{counts['dead']}  error:{counts['error']}        ")

    # ── Phase 2: parallel Wayback checks for dead URLs ───────────────────────
    dead_urls = [u for u in urls if live_results.get(u) == "DEAD"]
    total_dead = len(dead_urls)
    wb_counts = {"done": 0, "yes": 0, "no": 0, "error": 0, "fallback": 0}

    def _progress2() -> str:
        d = wb_counts["done"]
        base = (
            f"  [{d:{len(str(total_dead))}}/{total_dead}  "
            f"yes:{wb_counts['yes']}  no:{wb_counts['no']}  "
            f"error:{wb_counts['error']}]          "
        )
        if recheck_wayback:
            base = (
                f"  [{d:{len(str(total_dead))}}/{total_dead}  "
                f"yes:{wb_counts['yes']}  no:{wb_counts['no']}  "
                f"error:{wb_counts['error']}  fallback:{wb_counts['fallback']}]          "
            )
        return base

    def _wb_check_one(url: str) -> tuple[str, tuple[str, str, str]]:
        result = check_wayback(url)
        time.sleep(0.05)
        return url, result

    wb_workers = min(WAYBACK_WORKERS, total_dead) if total_dead else 1
    recheck_updated = 0
    recheck_fallback_urls: list[str] = []
    print(f"\nPhase 2 — Wayback checks ({total_dead} dead URLs, {wb_workers} workers)...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=wb_workers) as ex:
        for url, (wayback, snap_url, ts) in ex.map(_wb_check_one, dead_urls):
            # On error during --recheck-wayback, fall back to the old snapshot
            if wayback.startswith("ERROR") and url in _wayback_fallback:
                old_url, old_ts = _wayback_fallback[url]
                error_msg = wayback
                wayback, snap_url, ts = "YES", old_url, old_ts
                recheck_fallback_urls.append(url)
                with print_lock:
                    wb_counts["fallback"] += 1
                    print(f"\r  FALLBACK [{error_msg}]  {url}")
            if recheck_wayback and wayback == "YES":
                old_url, _ = _wayback_fallback.get(url, (snap_url, ""))
                if snap_url != old_url:
                    recheck_updated += 1
            _write((url, "DEAD", wayback, snap_url, ts))
            with print_lock:
                wb_counts["done"] += 1
                if wayback == "YES":
                    tally["wb_yes"] += 1
                    wb_counts["yes"] += 1
                    print(f"\r  YES  {url}")
                    print(f"       {snap_url}")
                elif wayback == "NO":
                    tally["wb_no"] += 1
                    wb_counts["no"] += 1
                else:
                    tally["wb_err"] += 1
                    wb_counts["error"] += 1
                    print(f"\r  {wayback}  {url}")
                print(_progress2(), end="\r", flush=True)
    print(f"\r  done: {total_dead}  yes:{wb_counts['yes']}  "
          f"no:{wb_counts['no']}  error:{wb_counts['error']}        ")

    out.close()

    # ── Dedup TSV after --recheck-wayback ─────────────────────────────────────
    # Prior rows + Phase 2 appends may have left duplicate entries (each DEAD+YES
    # URL appears twice: once from prior, once from Phase 2). Rewrite atomically.
    if recheck_wayback:
        rows = _read_tsv(OUTPUT)
        seen: dict[str, tuple[str, str, str, str]] = {}
        for url, live, wayback, wb_url, ts in rows:
            seen[url] = (live, wayback, wb_url, ts)  # last value wins
        tmp = OUTPUT.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            f.write("url\tlive\twayback\twayback_url\twayback_timestamp\n")
            for url, (live, wayback, wb_url, ts) in seen.items():
                f.write(f"{url}\t{live}\t{wayback}\t{wb_url}\t{ts}\n")
        tmp.replace(OUTPUT)

    # ── Summary ───────────────────────────────────────────────────────────────
    total_checked = len(prior) + n
    tally["dead"] += len(dead_urls)

    # Write/clear fallbacks file
    if recheck_wayback:
        if recheck_fallback_urls:
            FALLBACKS_FILE.write_text("\n".join(recheck_fallback_urls) + "\n", encoding="utf-8")
        elif FALLBACKS_FILE.exists():
            FALLBACKS_FILE.unlink()

    recheck_note  = (f"  ← {recheck_updated} snapshots updated to more recent"
                     if recheck_wayback and recheck_updated else "")
    wb_err_note   = "  ← rerun with --recheck-errors" if tally["wb_err"] else ""
    live_err_note = "  ← rerun with --recheck-errors" if tally["live_err"] else ""
    fallback_note = (f"  ← {len(recheck_fallback_urls)} fell back; rerun --recheck-wayback to retry"
                     if recheck_wayback and recheck_fallback_urls else "")

    print(f"\n── Summary ──────────────────────────────────────────")
    print(f"  URLs checked     : {total_checked}")
    print(f"  ├─ Live          : {tally['live']}")
    print(f"  ├─ Dead          : {tally['dead']}{recheck_note}")
    print(f"  │    Wayback YES : {tally['wb_yes']}{fallback_note}")
    print(f"  │    Wayback NO  : {tally['wb_no']}")
    print(f"  │    Wayback err : {tally['wb_err']}{wb_err_note}")
    print(f"  └─ Live chk err  : {tally['live_err']}  (wayback skipped){live_err_note}")
    print(f"  Saved to         : {OUTPUT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
