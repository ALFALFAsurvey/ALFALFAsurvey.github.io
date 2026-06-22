"""
fix_naic_links.py
=================
Rewrites all http://www.naic.edu/~a2010/PATH (and %7Ea2010 variant) links in
HTML/HTM files to relative links pointing into aweb/.

Resolution logic per link:
  1. aweb/PATH is a file  →  relative link (computed per source file)
  2. aweb/PATH is a dir with index.html  →  relative link to dir/index.html
  3. Neither  →  leave original NAIC URL unchanged (logged as unresolved)

Scans both aweb/ and rwebhtml/ directories.
DRY_RUN = True by default — set False to write changes.

Usage:
  python fix_naic_links.py
"""

import os
import re
from pathlib import Path

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_ROOT = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
AWEB      = REPO_ROOT / "aweb"
DRY_RUN   = False   # Set False to write changes

HTML_DIRS = ["aweb", "rwebhtml"]

# ─── Regex ────────────────────────────────────────────────────────────────────

# Matches both ~a2010 and %7Ea2010 (URL-encoded tilde) variants, http or https
NAIC_A2010_RE = re.compile(
    r'https?://www\.naic\.edu/(?:~|%7[Ee])a2010(/[^"\'<>\s]*)?',
    re.IGNORECASE,
)

# ─── Resolver ────────────────────────────────────────────────────────────────

def resolve_naic(match: re.Match, file_path: Path) -> tuple[str, str]:
    """Return (new_url, tag) where tag is 'relative' or 'unresolved'."""
    original = match.group(0)
    suffix   = match.group(1) or ""

    # Normalize double slashes, strip leading /, and strip trailing %22 (encoded quote)
    suffix = re.sub(r"//+", "/", suffix).lstrip("/")
    suffix = re.sub(r"%22$", "", suffix, flags=re.IGNORECASE)

    if not suffix:
        # Bare ~a2010 or ~a2010/ → aweb/index.html
        target_abs = AWEB / "index.html"
    else:
        target_abs = AWEB / suffix

    if target_abs.is_file():
        rel = os.path.relpath(target_abs, file_path.parent).replace(os.sep, "/")
        return rel, "relative"

    if target_abs.is_dir():
        rel = os.path.relpath(target_abs, file_path.parent).replace(os.sep, "/") + "/"
        return rel, "relative"

    return original, "unresolved"


# ─── Per-file processing ──────────────────────────────────────────────────────

def process_file(file_path: Path) -> list[tuple[str, str, str]]:
    """Process one file. Returns list of (old_url, new_url, tag)."""
    text    = file_path.read_text(encoding="utf-8", errors="replace")
    changes = []

    def replacer(m):
        old      = m.group(0)
        new, tag = resolve_naic(m, file_path)
        changes.append((old, new, tag))
        return new

    new_text = NAIC_A2010_RE.sub(replacer, text)

    if not DRY_RUN and any(tag == "relative" for _, _, tag in changes):
        file_path.write_text(new_text, encoding="utf-8")

    return changes


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    total_files   = 0
    changed_files = 0
    counts        = {"relative": 0, "unresolved": 0}
    unresolved    = []

    for dir_name in HTML_DIRS:
        search_dir = REPO_ROOT / dir_name
        if not search_dir.exists():
            print(f"Skipping {dir_name}/ (not found)")
            continue

        for ext in ("*.html", "*.htm"):
            for html_file in sorted(search_dir.rglob(ext)):
                total_files += 1
                changes = process_file(html_file)
                if not changes:
                    continue

                has_relative = any(tag == "relative" for _, _, tag in changes)
                if has_relative:
                    changed_files += 1

                rel = html_file.relative_to(REPO_ROOT)
                print(f"\n  {'[DRY]' if DRY_RUN else '[MOD]'} {rel}")

                for old, new, tag in changes:
                    counts[tag] += 1
                    label = {"relative": "→ rel    ", "unresolved": "→ ???    "}[tag]
                    print(f"    {label}  {old}")
                    if tag == "relative":
                        print(f"             {new}")
                    else:
                        unresolved.append((str(rel), old))

    print()
    print(f"Total files scanned   : {total_files}")
    print(f"Files with NAIC links : {changed_files}")
    print(f"  → relative links    : {counts['relative']}")
    print(f"  → unresolved (kept) : {counts['unresolved']}")

    if unresolved:
        print(f"\nUnresolved NAIC ~a2010 URLs ({len(unresolved)}):")
        for f, u in unresolved:
            print(f"  {f}: {u}")

    if DRY_RUN:
        print("\nDRY RUN — no files modified. Set DRY_RUN = False to apply.")
    else:
        print("\nDone.")


if __name__ == "__main__":
    main()
