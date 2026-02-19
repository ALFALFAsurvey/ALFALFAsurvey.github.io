"""
ALFALFA Website PHP → HTML Converter
=====================================
Converts the rweb PHP archive to a static HTML site suitable for GitHub Pages.

What this script does:
  1. Walks all files in INPUT_DIR
  2. Skips explicitly listed files (bannermenu.php, bannerone.php, one.php)
  3. For .php files:
       a. Has bannermenu include → replace with inlined banner HTML, rename to .html
       b. Has other PHP (no bannermenu) → copy as-is, log for manual review
       c. No PHP at all → rename to .html as-is
  4. For all other files → copy as-is
  5. Second pass: rewrites all .php links to .html in output HTML files

Usage:
  - Set DRY_RUN = True to preview actions without writing any files
  - Set DRY_RUN = False to actually perform the conversion
  - Set INPUT_DIR and OUTPUT_DIR to the correct paths
"""

from pathlib import Path
import re
import shutil

# ─── Configuration ────────────────────────────────────────────────────────────

INPUT_DIR  = Path("/Users/lleisman/Luke/web/ALFALFA/rweb")
OUTPUT_DIR = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/rwebhtml")

DRY_RUN = True  # Set to False to actually write files

# Files to skip entirely
SKIP_FILES = {"bannermenu.php", "bannerone.php", "one.php"}

# ─── Regexes ──────────────────────────────────────────────────────────────────

# Match the bannermenu PHP include in various forms
BANNER_REGEX = re.compile(
    r'<\?php\s*include\s+["\'][^"\']*bannermenu\.php["\'];?\s*\?>',
    re.IGNORECASE | re.DOTALL
)

# Detect any PHP opening tag
ANY_PHP_REGEX = re.compile(r'<\?php', re.IGNORECASE)

# Match internal .php hrefs for link rewriting
PHP_LINK_REGEX = re.compile(r'(href=["\'])([^"\'#?]+\.php)(["\'])', re.IGNORECASE)

# ─── Banner HTML Template ─────────────────────────────────────────────────────
# {root} is replaced with the relative path back to the site root (e.g. "../../")
# This ensures nav links work correctly from any subdirectory depth.

BANNER_TEMPLATE = """\
<center>
  <img src="{root}alfalfabanner.jpg"
       width="690" height="80" border="0" alt="ALFALFA">
</center>
<center>
  <h4>
    <font color="#008000">
      The <u>A</u>recibo <u>L</u>egacy <u>F</u>ast <u>ALFA</u> Survey
    </font>
  </h4>
</center>
<center>
  <div id="navbar">
    <a href="{root}index.html" class="current">Main</a>
    <a href="{root}people.html">People</a>
    <a href="{root}science.html">Science</a>
    <a href="{root}scheds/index.html">Schedule</a>
    <a href="{root}data/index.html">Data</a>
    <a href="{root}docs/index.html">Documentation</a>
    <a href="{root}links.html">Links</a>
    <a href="{root}pubs.html">Publications</a>
    <a href="{root}ugrad/index.html">Undergrads</a>
    <a href="{root}epo/index.html">Non-experts</a>
    <a href="{root}news/index.html">News/Events</a>
    <a href="http://caborojo.astro.cornell.edu/alfalfalog/index.php">Observing/Data Team</a>
  </div>
</center>
<hr align="center" width="800">
"""

# ─── Counters and Tracking ────────────────────────────────────────────────────

converted_count = 0   # bannermenu replaced → .html
kept_php_count  = 0   # other PHP kept as .php
renamed_count   = 0   # no PHP inside → renamed to .html
copied_count    = 0   # non-PHP files copied
skipped_count   = 0   # explicitly skipped files

# Relative paths (from OUTPUT_DIR) of all files renamed .php → .html
# Used by the link rewriter to know which .php links to update
renamed_files = set()

# Files kept as PHP, listed in the final report for manual review
kept_php_files = []


# ─── Helpers ──────────────────────────────────────────────────────────────────

def get_root_prefix(dest_path: Path) -> str:
    """
    Returns the relative path prefix back to the output root.
    e.g. a file at rwebhtml/projects/summs/foo.html → "../../"
         a file at rwebhtml/index.html              → ""
    """
    depth = len(dest_path.relative_to(OUTPUT_DIR).parts) - 1
    return "../" * depth


def safe_write(path: Path, content: str = None, copy_from: Path = None):
    """Write or copy a file, respecting DRY_RUN mode."""
    if DRY_RUN:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if copy_from:
        shutil.copy2(copy_from, path)
    else:
        path.write_text(content, encoding="utf-8", errors="replace")


# ─── File Processors ──────────────────────────────────────────────────────────

def process_php_file(src_path: Path):
    global converted_count, kept_php_count, renamed_count

    relative_path = src_path.relative_to(INPUT_DIR)
    dest_path     = OUTPUT_DIR / relative_path

    text = src_path.read_text(encoding="utf-8", errors="ignore")

    # Case 1: Has bannermenu include → inline the banner, rename to .html
    if BANNER_REGEX.search(text):
        dest_path = dest_path.with_suffix(".html")
        root      = get_root_prefix(dest_path)
        banner    = BANNER_TEMPLATE.format(root=root)
        new_text  = BANNER_REGEX.sub(banner, text)

        out_rel = dest_path.relative_to(OUTPUT_DIR)
        print(f"  [CONVERT]     {relative_path}  →  {out_rel}")
        converted_count += 1
        renamed_files.add(out_rel)
        safe_write(dest_path, content=new_text)

    # Case 2: Has other PHP but no bannermenu → keep as-is, flag for manual review
    elif ANY_PHP_REGEX.search(text):
        print(f"  [KEEP PHP]    {relative_path}  ← needs manual review")
        kept_php_count += 1
        kept_php_files.append(str(relative_path))
        safe_write(dest_path, copy_from=src_path)

    # Case 3: .php in name only, no PHP inside → just rename to .html
    else:
        dest_path = dest_path.with_suffix(".html")
        out_rel   = dest_path.relative_to(OUTPUT_DIR)
        print(f"  [RENAME]      {relative_path}  →  {out_rel}")
        renamed_count += 1
        renamed_files.add(out_rel)
        safe_write(dest_path, content=text)


def process_other_file(src_path: Path):
    global copied_count

    relative_path = src_path.relative_to(INPUT_DIR)
    dest_path     = OUTPUT_DIR / relative_path

    print(f"  [COPY]        {relative_path}")
    copied_count += 1
    safe_write(dest_path, copy_from=src_path)


# ─── Link Rewriter ────────────────────────────────────────────────────────────

def rewrite_links():
    """
    Second pass: in every .html file in the output directory,
    rewrite href="foo.php" → href="foo.html" for any file that was renamed.
    Handles relative paths correctly regardless of subdirectory depth.
    """
    print("\n─── Rewriting internal .php links ───────────────────────────────────\n")

    updated_count = 0
    output_dir_resolved = OUTPUT_DIR.resolve()

    for file_path in sorted(OUTPUT_DIR.rglob("*.html")):
        relative_path = file_path.relative_to(OUTPUT_DIR)

        if DRY_RUN:
            print(f"  [CHECK LINKS] {relative_path}")
            continue

        text    = file_path.read_text(encoding="utf-8", errors="ignore")
        changed = False

        def replace_link(match):
            nonlocal changed
            prefix       = match.group(1)  # e.g. href="
            original_href = match.group(2)  # e.g. ../foo.php
            suffix       = match.group(3)  # e.g. "

            # Skip absolute URLs
            if original_href.startswith(("http://", "https://", "//")):
                return match.group(0)

            link_path    = Path(original_href)
            html_version = link_path.with_suffix(".html")

            # Resolve the link relative to the current file's directory
            current_dir  = file_path.parent
            try:
                resolved     = (current_dir / html_version).resolve()
                resolved_rel = resolved.relative_to(output_dir_resolved)
            except (ValueError, OSError):
                return match.group(0)  # can't resolve, leave alone

            if resolved_rel in renamed_files:
                changed = True
                return f'{prefix}{html_version}{suffix}'
            else:
                return match.group(0)

        new_text = PHP_LINK_REGEX.sub(replace_link, text)

        if changed:
            file_path.write_text(new_text, encoding="utf-8", errors="replace")
            print(f"  [LINKS FIXED] {relative_path}")
            updated_count += 1

    if not DRY_RUN:
        print(f"\n  Links updated in {updated_count} file(s).")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    global skipped_count

    if not INPUT_DIR.exists():
        print(f"ERROR: Input directory not found:\n  {INPUT_DIR}")
        return

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║         ALFALFA PHP → HTML Converter                         ║
╚══════════════════════════════════════════════════════════════╝
  Mode:     {'DRY RUN — no files will be written' if DRY_RUN else '⚠️  LIVE RUN — files will be written!'}
  Input:    {INPUT_DIR}
  Output:   {OUTPUT_DIR}
  Skipping: {', '.join(sorted(SKIP_FILES))}
""")

    # ── First pass: process all files ──────────────────────────────────────────
    print("─── Processing files ────────────────────────────────────────────────\n")

    for src_path in sorted(INPUT_DIR.rglob("*")):
        if not src_path.is_file():
            continue

        if src_path.name in SKIP_FILES:
            print(f"  [SKIP]        {src_path.relative_to(INPUT_DIR)}")
            skipped_count += 1
            continue

        if src_path.suffix.lower() == ".php":
            process_php_file(src_path)
        else:
            process_other_file(src_path)

    # ── Second pass: rewrite links ─────────────────────────────────────────────
    rewrite_links()

    # ── Summary ────────────────────────────────────────────────────────────────
    total = converted_count + kept_php_count + renamed_count + copied_count + skipped_count

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  SUMMARY                                                     ║
╠══════════════════════════════════════════════════════════════╣
  Converted  (bannermenu → HTML):  {converted_count:>4}
  Renamed    (PHP in name only):   {renamed_count:>4}
  Kept as PHP (needs review):      {kept_php_count:>4}
  Other files copied:              {copied_count:>4}
  Skipped:                         {skipped_count:>4}
  ───────────────────────────────────────────────
  Total files processed:           {total:>4}
╚══════════════════════════════════════════════════════════════╝
""")

    if kept_php_count > 0:
        print("⚠️  The following files contain PHP that needs manual review:")
        for f in kept_php_files:
            print(f"     • {f}")
        print()

    if DRY_RUN:
        print("ℹ️  DRY RUN complete — no files were written.")
        print("   Set DRY_RUN = False and re-run to perform the actual conversion.\n")
    else:
        print("✅ Conversion complete.\n")


if __name__ == "__main__":
    main()
