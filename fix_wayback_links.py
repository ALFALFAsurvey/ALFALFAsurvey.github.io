"""
fix_wayback_links.py
====================
Reads wayback_results.tsv and fixes broken links in HTML files:

  1. DEAD + YES wayback  →  replace original URL with Wayback archive URL
  2. DEAD + NO wayback   →  listed in dead_links_report.txt for manual review
  3. DEAD + ERROR        →  also listed in dead_links_report.txt

Set DRY_RUN = True to preview without writing files.

Usage:
  python fix_wayback_links.py
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_ROOT  = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
TSV_FILE   = REPO_ROOT / "wayback_results.tsv"
REPORT_FILE = REPO_ROOT / "dead_links_report.txt"
DRY_RUN        = True   # Set False to write changes
SAMPLE_COUNT   = 10      # Number of example replacements to print in dry-run mode

HTML_DIRS  = ["rwebhtml", "aweb"]
HTML_GLOBS = ["**/*.html", "*.html"]

# ─── Load TSV ─────────────────────────────────────────────────────────────────

def load_tsv(path: Path) -> tuple[dict[str, str], list[str]]:
    """
    Returns:
      replacements: {original_url: wayback_url}  for DEAD+YES rows
      dead_no_wayback: [original_url]             for DEAD rows without a usable wayback
    """
    replacements: dict[str, str] = {}
    dead_no_wayback: list[str] = []

    with path.open() as f:
        for i, line in enumerate(f):
            if i == 0:
                continue  # header
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            url, live, wayback, wayback_url = parts[0], parts[1], parts[2], parts[3]

            if live != "DEAD":
                continue

            if wayback == "YES" and wayback_url.startswith("http"):
                replacements[url] = wayback_url
            else:
                dead_no_wayback.append(url)

    return replacements, dead_no_wayback


# ─── Collect HTML files ───────────────────────────────────────────────────────

def collect_html_files() -> list[Path]:
    files: list[Path] = []
    for d in HTML_DIRS:
        base = REPO_ROOT / d
        if base.is_dir():
            files.extend(base.rglob("*.html"))
    # top-level html files
    for p in REPO_ROOT.glob("*.html"):
        files.append(p)
    return sorted(set(files))


# ─── URL matching ─────────────────────────────────────────────────────────────

def build_url_pattern(urls: list[str]) -> re.Pattern:
    """Build a single regex that matches any of the given URLs literally."""
    escaped = sorted((re.escape(u) for u in urls), key=len, reverse=True)
    return re.compile("|".join(escaped))


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    if not TSV_FILE.exists():
        print(f"ERROR: {TSV_FILE} not found. Run check_wayback.py first.")
        sys.exit(1)

    replacements, dead_no_wayback = load_tsv(TSV_FILE)
    print(f"Loaded {len(replacements)} replaceable URLs, {len(dead_no_wayback)} unresolvable dead URLs")

    html_files = collect_html_files()
    print(f"Found {len(html_files)} HTML files to scan")

    if not replacements and not dead_no_wayback:
        print("Nothing to do.")
        return

    replace_pattern = build_url_pattern(list(replacements)) if replacements else None

    total_replacements = 0
    files_modified = 0
    samples_shown = 0

    # dead_no_wayback: map url → set of files that reference it
    dead_occurrences: dict[str, set[str]] = defaultdict(set)
    dead_set = set(dead_no_wayback)

    for html_file in html_files:
        try:
            original = html_file.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            print(f"  SKIP {html_file}: {e}")
            continue

        rel = html_file.relative_to(REPO_ROOT)

        # ── Check for dead-no-wayback occurrences ──────────────────────────
        for dead_url in dead_set:
            if dead_url in original:
                dead_occurrences[dead_url].add(str(rel))

        # ── Apply replacements ─────────────────────────────────────────────
        if replace_pattern is None or not replace_pattern.search(original):
            continue

        count = [0]
        file_samples: list[tuple[str, str]] = []

        def replace_match(m: re.Match) -> str:
            old = m.group(0)
            new = replacements[old]
            count[0] += 1
            if DRY_RUN and samples_shown + len(file_samples) < SAMPLE_COUNT:
                file_samples.append((old, new))
            return new

        updated = replace_pattern.sub(replace_match, original)

        if count[0] == 0:
            continue

        total_replacements += count[0]
        files_modified += 1

        if DRY_RUN:
            print(f"  [DRY] {rel}: {count[0]} replacement(s)")
            for old, new in file_samples:
                print(f"    - {old}")
                print(f"    + {new}")
            samples_shown += len(file_samples)
        else:
            html_file.write_text(updated, encoding="utf-8")
            print(f"  WROTE {rel}: {count[0]} replacement(s)")

    # ── Summary ───────────────────────────────────────────────────────────────
    mode = "DRY RUN" if DRY_RUN else "LIVE"
    print(f"\n[{mode}] {total_replacements} URL replacements across {files_modified} files")

    # ── Dead-link report ──────────────────────────────────────────────────────
    write_report(dead_occurrences)


def write_report(dead_occurrences: dict[str, set[str]]):
    if not dead_occurrences:
        print("No unresolvable dead links found — no report written.")
        return

    # Invert: file → list of dead URLs
    by_file: dict[str, list[str]] = defaultdict(list)
    for url, files in sorted(dead_occurrences.items()):
        for f in sorted(files):
            by_file[f].append(url)

    lines = [
        "Dead links with no Wayback archive",
        "===================================",
        f"({len(dead_occurrences)} unique URLs across {len(by_file)} files)",
        "",
    ]
    for f in sorted(by_file):
        lines.append(f"## {f}")
        for url in sorted(by_file[f]):
            lines.append(f"  {url}")
        lines.append("")

    report_text = "\n".join(lines)
    REPORT_FILE.write_text(report_text, encoding="utf-8")
    print(f"\nReport written to {REPORT_FILE.relative_to(REPO_ROOT)}")
    print(f"  {len(dead_occurrences)} unique dead URLs (no wayback) in {len(by_file)} files")


if __name__ == "__main__":
    main()
