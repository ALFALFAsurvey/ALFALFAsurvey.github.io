"""
ALFALFA Website - Phase 2: Google Drive Sorter (v4)
====================================================
Sorts files in rwebhtml into two buckets:
  - Small/non-data files  → stay in rwebhtml, deleted from Google Drive
  - Large/data files      → stay on Google Drive, deleted from rwebhtml

Then updates all HTML links in rwebhtml to point to Google Drive sharing URLs
for any file that was moved to Drive.

Key design decisions in v4:
  - Drive DELETIONS use the local filesystem (mounted Google Drive for Desktop)
    instead of the API — orders of magnitude faster (no per-file HTTP calls)
  - The API is only used for ONE bulk read to get file IDs (needed for URLs)
    and ONE bulk permission update to make files public
  - drive_url_map.json is saved incrementally so link rewriting survives crashes
  - drive_index_cache.json caches the API index so reruns skip slow indexing
  - Fully resumable: safe to rerun after any interruption

Current state awareness:
  - If drive_url_map.json already exists, skip straight to link rewriting
  - If drive_index_cache.json exists, skip the API indexing step
  - Files already deleted from rwebhtml are skipped gracefully

Prerequisites:
  - Phase 1 (convert_alfalfa.py) must have been run first
  - token.json must exist (created by test_drive.py OAuth flow)
  - Google Drive for Desktop must be mounted and accessible
"""

from pathlib import Path
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
import re
import json
import time

# ─── Configuration ────────────────────────────────────────────────────────────

RWEBHTML_DIR  = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/rwebhtml")
DRIVE_DIR     = Path("/Users/lleisman/alfalfalegacy@gmail.com - Google Drive/My Drive/ALFALFAweb/rweb")

CREDS_FILE    = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/client_secret_699840800313-3bouvfpnsumgr369se929ohgr244fatv.apps.googleusercontent.com.json")
TOKEN_FILE    = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/token.json")
INDEX_CACHE   = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/drive_index_cache.json")
URL_MAP_FILE  = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/drive_url_map.json")
URL_MAP_FILE_DRY  = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/drive_url_map_dryrun.json")

RWEB_FOLDER_ID = "16koEvWzj_iORguIglf4-WWl4mfVZDzwY"

DRY_RUN = False  # Set to False to actually modify files

SIZE_THRESHOLD_BYTES = 100 * 1024  # 100 KB

LARGE_FILE_EXTENSIONS = {
    ".csv", ".tsv",
    ".xls", ".xlsx",
    ".pdf",
    ".ppt", ".pptx",
    ".doc", ".docx",
    ".zip", ".tar", ".gz",
    ".fits", ".dat"
}

JUNK_NAMES    = {".DS_Store"}
JUNK_SUFFIXES = {"~"}

SCOPES = ['https://www.googleapis.com/auth/drive']

MAX_RETRIES = 5
RETRY_DELAY = 2  # seconds, doubled on each retry

# ─── Auth ─────────────────────────────────────────────────────────────────────

def get_drive_service():
    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if not creds or not creds.valid:
        flow = InstalledAppFlow.from_client_secrets_file(str(CREDS_FILE), SCOPES)
        creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
    return build('drive', 'v3', credentials=creds)

# ─── Retry wrapper ────────────────────────────────────────────────────────────

def api_call_with_retry(fn, label="API call"):
    delay = RETRY_DELAY
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return fn()
        except Exception as e:
            if attempt == MAX_RETRIES:
                print(f"  ❌ {label} failed after {MAX_RETRIES} attempts: {e}")
                raise
            print(f"  ⚠️  {label} failed (attempt {attempt}/{MAX_RETRIES}): {e}")
            print(f"     Retrying in {delay}s...")
            time.sleep(delay)
            delay *= 2

# ─── Drive API index (one bulk read, cached) ──────────────────────────────────

def build_drive_index_api(service, folder_id, prefix=""):
    """Recursively build {rel_path → file_id} from Drive API."""
    index = {}
    page_token = None
    while True:
        response = api_call_with_retry(
            lambda pt=page_token: service.files().list(
                q=f"'{folder_id}' in parents and trashed=false",
                fields="nextPageToken, files(id, name, mimeType)",
                pageSize=1000,
                pageToken=pt
            ).execute(),
            label=f"list folder {prefix or 'root'}"
        )
        for item in response.get('files', []):
            rel_path = f"{prefix}{item['name']}" if prefix else item['name']
            if item['mimeType'] == 'application/vnd.google-apps.folder':
                sub = build_drive_index_api(service, item['id'], prefix=f"{rel_path}/")
                index.update(sub)
            else:
                index[rel_path] = item['id']
        page_token = response.get('nextPageToken')
        if not page_token:
            break
    return index


def load_drive_index(service):
    """Load Drive index from cache, or build and cache it."""
    if INDEX_CACHE.exists():
        print(f"  ✅ Loading Drive index from cache ({INDEX_CACHE.name})")
        print(f"     Delete {INDEX_CACHE.name} to force a fresh rebuild.\n")
        return json.loads(INDEX_CACHE.read_text())
    print("  Building Drive index via API (one-time, may take a minute)...")
    index = build_drive_index_api(service, RWEB_FOLDER_ID)
    INDEX_CACHE.write_text(json.dumps(index, indent=2))
    print(f"  ✅ Indexed {len(index)} files. Cached to {INDEX_CACHE.name}\n")
    return index


def drive_lookup(drive_index, rel_str):
    """
    Look up rel_str in drive_index.
    Falls back to .php version for .html/.htm files (phase 1 renamed them).
    Returns (file_id, drive_key) or (None, None).
    """
    key = rel_str.replace("\\", "/")
    if key in drive_index:
        return drive_index[key], key
    p = Path(key)
    if p.suffix.lower() in {".html", ".htm"}:
        php_key = str(p.with_suffix(".php"))
        if php_key in drive_index:
            return drive_index[php_key], php_key
    return None, None

# ─── Make files public (bulk, via API) ───────────────────────────────────────

def make_public_and_build_url_map(service, drive_index, files_on_drive):
    """
    For each (rel_str, file_id) in files_on_drive:
      - Make the file publicly readable (API call)
      - Record the sharing URL
    Saves url_map incrementally to URL_MAP_FILE (or URL_MAP_FILE_DRY in dry run).
    Returns the complete url_map dict.
    """
    save_path = URL_MAP_FILE_DRY if DRY_RUN else URL_MAP_FILE

    # Load any previously saved progress
    if save_path.exists():
        url_map = json.loads(save_path.read_text())
        print(f"  ✅ Resuming — {len(url_map)} URLs already saved in {save_path.name}")
    else:
        url_map = {}

    todo = [(rel, fid) for rel, fid in files_on_drive if rel not in url_map]
    print(f"  Processing {len(todo)} files (already done: {len(url_map)})...\n")

    for i, (rel_str, file_id) in enumerate(todo):
        url_map[rel_str] = f"https://drive.google.com/file/d/{file_id}/view"
        if not DRY_RUN:
            api_call_with_retry(
                lambda fid=file_id: service.permissions().create(
                    fileId=fid,
                    body={"type": "anyone", "role": "reader"},
                ).execute(),
                label=f"make public {rel_str}"
            )
        # Save after every file so progress survives crashes
        save_path.write_text(json.dumps(url_map, indent=2))

        if (i + 1) % 50 == 0:
            print(f"  ... {i + 1}/{len(todo)} done")

    return url_map

# ─── Local filesystem delete (fast!) ─────────────────────────────────────────

def delete_local(path: Path, label: str):
    """Delete a file from the local filesystem (rwebhtml or mounted Drive)."""
    if DRY_RUN:
        return
    if path.exists():
        path.unlink()
        print(f"  [DELETE] {label}")

# ─── File classification ──────────────────────────────────────────────────────

def is_junk(path: Path) -> bool:
    if path.name in JUNK_NAMES:
        return True
    if any(path.name.endswith(s) for s in JUNK_SUFFIXES):
        return True
    return False


def should_go_to_drive(path: Path) -> bool:
    if path.suffix.lower() in LARGE_FILE_EXTENSIONS:
        return True
    if path.stat().st_size >= SIZE_THRESHOLD_BYTES:
        return True
    return False

# ─── Link rewriter ────────────────────────────────────────────────────────────

LINK_REGEX = re.compile(
    r'((?:href|src)=["\'])([^"\'#?]+)(["\'])',
    re.IGNORECASE
)

def rewrite_links_in_file(file_path: Path, url_map: dict):
    text = file_path.read_text(encoding="utf-8", errors="ignore")
    changed = False
    current_dir = file_path.parent
    rwebhtml_resolved = RWEBHTML_DIR.resolve()

    def replace_link(match):
        nonlocal changed
        prefix = match.group(1)
        href   = match.group(2)
        suffix = match.group(3)

        if href.startswith(("http://", "https://", "//", "mailto:", "#")):
            return match.group(0)

        try:
            resolved    = (current_dir / href).resolve()
            rel_to_root = resolved.relative_to(rwebhtml_resolved)
            rel_str     = str(rel_to_root)
        except (ValueError, OSError):
            return match.group(0)

        if rel_str in url_map:
            changed = True
            return f'{prefix}{url_map[rel_str]}{suffix}'
        return match.group(0)

    new_text = LINK_REGEX.sub(replace_link, text)
    if changed:
        if not DRY_RUN:
            file_path.write_text(new_text, encoding="utf-8", errors="replace")
        return True
    return False

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    if not RWEBHTML_DIR.exists():
        print(f"ERROR: rwebhtml not found: {RWEBHTML_DIR}"); return
    if not DRIVE_DIR.exists():
        print(f"ERROR: Drive not mounted: {DRIVE_DIR}"); return

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║         ALFALFA Phase 2: Google Drive Sorter  (v4)           ║
╚══════════════════════════════════════════════════════════════╝
  Mode:        {'DRY RUN — no files will be modified' if DRY_RUN else '⚠️  LIVE RUN — files will be modified!'}
  rwebhtml:    {RWEBHTML_DIR}
  Drive mount: {DRIVE_DIR}
  URL map:     {'EXISTS — will skip to link rewriting' if URL_MAP_FILE.exists() else 'not found — will build'}
  Index cache: {'EXISTS — will skip API indexing' if INDEX_CACHE.exists() else 'not found — will query API'}
""")

    # ── Step 1: Classify all rwebhtml files ────────────────────────────────────
    print("─── Step 1: Classifying rwebhtml files ──────────────────────────────\n")

    junk_files = []
    to_drive   = []
    keep_local = []

    for local_path in sorted(RWEBHTML_DIR.rglob("*")):
        if not local_path.is_file():
            continue
        rel_str = str(local_path.relative_to(RWEBHTML_DIR))
        if is_junk(local_path):
            junk_files.append((local_path, rel_str))
        elif should_go_to_drive(local_path):
            to_drive.append((local_path, rel_str))
        else:
            keep_local.append((local_path, rel_str))

    print(f"  Junk files:                  {len(junk_files)}")
    print(f"  Should be on Drive:          {len(to_drive)}")
    print(f"  Stay in rwebhtml:            {len(keep_local)}\n")

    # ── Step 2: Build or load URL map ─────────────────────────────────────────
    # If URL map already exists and is complete, skip straight to link rewriting
    if URL_MAP_FILE.exists():
        url_map = json.loads(URL_MAP_FILE.read_text())
        print(f"─── Step 2: URL map loaded from {URL_MAP_FILE.name} ({len(url_map)} entries) ───\n")
        print("  Skipping Drive indexing and permission updates.\n")
    else:
        print("─── Step 2: Building Drive URL map ──────────────────────────────────\n")

        # Connect to API
        service = get_drive_service()
        print("  ✅ Connected to Drive API\n")

        # Load or build index
        drive_index = load_drive_index(service)

        # Find which "to_drive" files are actually on Drive and get their IDs
        files_on_drive  = []  # (rel_str, file_id)
        not_on_drive    = []

        for local_path, rel_str in to_drive:
            file_id, drive_key = drive_lookup(drive_index, rel_str)
            if file_id:
                files_on_drive.append((rel_str, file_id))
            else:
                not_on_drive.append(rel_str)

        # Also find Drive files for files already deleted from rwebhtml
        # (routing was done in a previous run — we still need their URLs)
        drive_only = []
        for drive_path in DRIVE_DIR.rglob("*"):
            if not drive_path.is_file():
                continue
            rel_str   = str(drive_path.relative_to(DRIVE_DIR))
            local_path = RWEBHTML_DIR / rel_str
            # Check both .php and .html variants
            html_rel  = str(Path(rel_str).with_suffix(".html"))
            local_html = RWEBHTML_DIR / html_rel
            if not local_path.exists() and not local_html.exists():
                # This file is on Drive but not in rwebhtml — it was already routed
                file_id, _ = drive_lookup(drive_index, rel_str)
                if file_id:
                    drive_only.append((rel_str, file_id))  # use original filename, not .html version

        all_drive_files = files_on_drive + drive_only
        print(f"  Files to make public: {len(all_drive_files)}")
        print(f"    • In current rwebhtml (still to delete): {len(files_on_drive)}")
        print(f"    • Already deleted from rwebhtml:         {len(drive_only)}\n")

        if not_on_drive:
            print(f"  ⚠️  {len(not_on_drive)} large files not found on Drive:")
            for f in not_on_drive[:10]:
                print(f"       • {f}")
            if len(not_on_drive) > 10:
                print(f"       ... and {len(not_on_drive) - 10} more")
            print()

        url_map = make_public_and_build_url_map(service, drive_index, all_drive_files)
        print(f"\n  ✅ URL map complete: {len(url_map)} entries saved to {URL_MAP_FILE.name}\n")

    # ── Step 3: Delete junk files ──────────────────────────────────────────────
    print("─── Step 3: Deleting junk files ─────────────────────────────────────\n")

    junk_deleted = 0
    for local_path, rel_str in junk_files:
        # Delete from rwebhtml
        delete_local(local_path, f"rwebhtml/{rel_str}")
        # Delete from Drive mount if present
        drive_path = DRIVE_DIR / rel_str
        delete_local(drive_path, f"Drive/{rel_str}")
        print(f"  [JUNK] {rel_str}")
        junk_deleted += 1

    # ── Step 4: Move large files — delete from rwebhtml (already on Drive) ─────
    print("\n─── Step 4: Removing large files from rwebhtml ──────────────────────\n")

    routed = 0
    already_gone = 0
    for local_path, rel_str in to_drive:
        if not local_path.exists():
            already_gone += 1
            continue
        delete_local(local_path, f"rwebhtml/{rel_str}")
        routed += 1

    print(f"  Deleted from rwebhtml: {routed}")
    print(f"  Already gone (previous run): {already_gone}\n")

    # ── Step 5: Delete small files from Drive mount (dedup) ───────────────────
    print("─── Step 5: Removing small files from Drive mount (dedup) ───────────\n")

    dedup_deleted = 0
    dedup_missing = 0
    for local_path, rel_str in keep_local:
        # Try direct match and .php fallback
        drive_path = DRIVE_DIR / rel_str
        if not drive_path.exists():
            # Try .php version for .html files
            p = Path(rel_str)
            if p.suffix.lower() in {".html", ".htm"}:
                drive_path = DRIVE_DIR / p.with_suffix(".php")
        if drive_path.exists():
            delete_local(drive_path, f"Drive/{rel_str}")
            dedup_deleted += 1
        else:
            dedup_missing += 1

    print(f"  Deleted from Drive: {dedup_deleted}")
    print(f"  Not on Drive (already deleted or never there): {dedup_missing}\n")

    # ── Step 6: Rewrite links in HTML files ───────────────────────────────────
    print("─── Step 6: Rewriting links in HTML files ───────────────────────────\n")

    links_updated = 0
    for html_file in sorted(RWEBHTML_DIR.rglob("*.html")):
        if is_junk(html_file):
            continue
        updated = rewrite_links_in_file(html_file, url_map)
        if updated:
            print(f"  [LINKS FIXED] {html_file.relative_to(RWEBHTML_DIR)}")
            links_updated += 1

    # ── Summary ───────────────────────────────────────────────────────────────
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  SUMMARY                                                     ║
╠══════════════════════════════════════════════════════════════╣
  Junk files deleted:                  {junk_deleted:>4}
  Large files removed from rwebhtml:   {routed + already_gone:>4}
    • Deleted this run:                {routed:>4}
    • Already gone (prev run):         {already_gone:>4}
  Small files removed from Drive:      {dedup_deleted:>4}
  HTML files with updated links:       {links_updated:>4}
  Drive URLs in map:                   {len(url_map):>4}
╚══════════════════════════════════════════════════════════════╝
""")

    if DRY_RUN:
        print("ℹ️  DRY RUN complete — no files were modified.")
        print("   Set DRY_RUN = False and re-run to perform the actual sort.\n")
    else:
        print("✅ Phase 2 complete!")
        print(f"   drive_url_map.json and drive_index_cache.json can be kept for reference")
        print(f"   or deleted — they are not needed by the website.\n")


if __name__ == "__main__":
    main()
