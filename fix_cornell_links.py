"""
fix_cornell_links.py
====================
Rewrites all http://egg.astro.cornell.edu/alfalfa/PATH links in HTML files
using a three-way decision per link:

  1. File exists in rwebhtml/  →  relative link  (computed per source file)
  2. Path found in drive_url_map.json  →  Google Drive URL
  3. Neither  →  leave original Cornell URL unchanged (logged as unresolved)

Rules:
  - .php extensions are converted to .html before checking rwebhtml/
  - Trailing slash or bare /alfalfa → rwebhtml/index.html
  - Non-/alfalfa Cornell URLs (e.g. /precursor/) are always left unchanged
  - Set DRY_RUN = True to preview without modifying files

Usage:
  python fix_cornell_links.py
"""

import json
import os
import re
from pathlib import Path

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_ROOT      = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
RWEBHTML       = REPO_ROOT / "rwebhtml"
DRIVE_MAP_FILE = REPO_ROOT / "drive_url_map.json"
DRY_RUN        = True   # Set False to write changes

# Directories to process (relative to REPO_ROOT)
HTML_DIRS = ["rwebhtml", "aweb"]

# ─── Load Drive map ───────────────────────────────────────────────────────────

def load_drive_map() -> dict[str, str]:
    if not DRIVE_MAP_FILE.exists():
        print(f"Warning: {DRIVE_MAP_FILE} not found — Drive fallback disabled.")
        return {}
    with DRIVE_MAP_FILE.open() as f:
        return json.load(f)

DRIVE_MAP = load_drive_map()

# ─── Regex ────────────────────────────────────────────────────────────────────

CORNELL_RE = re.compile(
    r'https?://egg\.astro\.cornell\.edu/alfalfa(/[^"\'<>\s]*)?',
    re.IGNORECASE
)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def path_to_html(path_str: str) -> str:
    """Convert .php extension to .html."""
    if path_str.lower().endswith(".php"):
        return path_str[:-4] + ".html"
    return path_str


def resolve_cornell(match: re.Match, file_path: Path) -> tuple[str, str]:
    """
    Return (new_url, resolution_tag) for a Cornell URL match.

    resolution_tag is one of: 'relative', 'drive', 'unresolved'
    """
    original  = match.group(0)
    suffix    = match.group(1) or ""

    # Normalize double slashes
    suffix = re.sub(r"//+", "/", suffix)
    suffix = suffix.lstrip("/")

    # Bare /alfalfa or /alfalfa/ → index.html
    if not suffix:
        html_suffix = "index.html"
    else:
        html_suffix = path_to_html(suffix)

    # 1. Check if file exists in rwebhtml/
    target_abs = RWEBHTML / html_suffix
    if target_abs.is_file():
        rel = os.path.relpath(target_abs, file_path.parent).replace(os.sep, "/")
        return rel, "relative"
    # Directory URL (e.g. /alfalfa/ugradteam/) → link to index.html inside it
    if target_abs.is_dir():
        index_abs = target_abs / "index.html"
        if index_abs.is_file():
            rel = os.path.relpath(index_abs, file_path.parent).replace(os.sep, "/")
            return rel, "relative"

    # 2. Check drive map (keyed by the raw suffix, then the .html-converted one)
    for key in (suffix, html_suffix):
        if key in DRIVE_MAP:
            return DRIVE_MAP[key], "drive"

    # 3. Leave unchanged
    return original, "unresolved"


# ─── Per-file processing ──────────────────────────────────────────────────────

def process_file(file_path: Path) -> list[tuple[str, str, str]]:
    """
    Process one HTML file.
    Returns list of (old_url, new_url, tag) for every Cornell link found.
    """
    text    = file_path.read_text(encoding="utf-8", errors="replace")
    changes = []

    def replacer(m):
        old = m.group(0)
        new, tag = resolve_cornell(m, file_path)
        changes.append((old, new, tag))
        return new

    new_text = CORNELL_RE.sub(replacer, text)

    actually_changed = any(tag != "unresolved" for _, _, tag in changes)
    if not DRY_RUN and actually_changed:
        file_path.write_text(new_text, encoding="utf-8")
    return changes


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    total_files    = 0
    changed_files  = 0
    tag_counts     = {"relative": 0, "drive": 0, "unresolved": 0}
    unresolved_all = []  # (file_rel, old_url)

    for dir_name in HTML_DIRS:
        search_dir = REPO_ROOT / dir_name
        if not search_dir.exists():
            print(f"Skipping {dir_name}/ (not found)")
            continue

        for html_file in sorted(search_dir.rglob("*.html")):
            total_files += 1
            changes = process_file(html_file)
            if not changes:
                continue

            actually_changed = any(tag != "unresolved" for _, _, tag in changes)
            if actually_changed:
                changed_files += 1
            rel = html_file.relative_to(REPO_ROOT)
            print(f"\n  {'[DRY]' if DRY_RUN else '[MOD]'} {rel}")

            for old, new, tag in changes:
                tag_counts[tag] += 1
                label = {"relative": "→ rel  ", "drive": "→ drive", "unresolved": "→ ???  "}[tag]
                print(f"    {label}  {old}")
                if tag != "unresolved":
                    print(f"             {new}")
                if tag == "unresolved":
                    unresolved_all.append((str(rel), old))

    print()
    print(f"Total HTML files scanned : {total_files}")
    print(f"Files with Cornell links : {changed_files}")
    print(f"  → relative links       : {tag_counts['relative']}")
    print(f"  → drive links          : {tag_counts['drive']}")
    print(f"  → unresolved (kept)    : {tag_counts['unresolved']}")

    if unresolved_all:
        print(f"\nUnresolved Cornell URLs ({len(unresolved_all)}):")
        for f, u in unresolved_all:
            print(f"  {f}: {u}")

    if DRY_RUN:
        print("\nDRY RUN — no files modified. Set DRY_RUN = False to apply.")
    else:
        print("\nDone.")


if __name__ == "__main__":
    main()
