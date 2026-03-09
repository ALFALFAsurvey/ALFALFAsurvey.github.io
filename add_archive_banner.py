"""
add_archive_banner.py
=====================
Inserts the archive notice banner into every HTML file in rwebhtml/
that doesn't already have one. The link back to the Legacy Homepage
is computed as a relative path from each file to the repo root index.html.

Banner is inserted just before <body> (or after </head> if no <body> tag).
Set DRY_RUN = True to preview without writing.
"""

import os
import re
from pathlib import Path

REPO_ROOT  = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io")
RWEBHTML   = REPO_ROOT / "rwebhtml"
ROOT_INDEX = REPO_ROOT / "index.html"
DRY_RUN    = True

BANNER_TEMPLATE = """\
<div style="background:#f5f5f5; border-bottom:2px solid #008000; \
padding:8px 20px; font-family:sans-serif; font-size:0.9em;">
  \U0001f4c1 This is an archived page from the original ALFALFA Survey website. \
Return to the <a href="{link}">ALFALFA Legacy Homepage</a>.
</div>
"""

# Matches the insertion point: just before <body (case-insensitive)
BODY_RE = re.compile(r'(<body[\s>])', re.IGNORECASE)
HEAD_END_RE = re.compile(r'(</head>)', re.IGNORECASE)


def insert_banner(text: str, banner: str) -> str | None:
    """Return modified text, or None if no suitable insertion point found."""
    m = BODY_RE.search(text)
    if m:
        return text[:m.start()] + banner + text[m.start():]
    m = HEAD_END_RE.search(text)
    if m:
        return text[:m.end()] + "\n" + banner + text[m.end():]
    return None


def main():
    added = skipped_has_banner = skipped_no_anchor = 0

    for html_file in sorted(RWEBHTML.rglob("*.html")):
        text = html_file.read_text(encoding="utf-8", errors="replace")

        if "archived page" in text:
            skipped_has_banner += 1
            continue

        link = os.path.relpath(ROOT_INDEX, html_file.parent).replace(os.sep, "/")
        banner = BANNER_TEMPLATE.format(link=link)
        new_text = insert_banner(text, banner)

        if new_text is None:
            skipped_no_anchor += 1
            print(f"  [NO ANCHOR] {html_file.relative_to(REPO_ROOT)}")
            continue

        added += 1
        if not DRY_RUN:
            html_file.write_text(new_text, encoding="utf-8")
        else:
            print(f"  [DRY] {html_file.relative_to(REPO_ROOT)}  →  link: {link}")

    print()
    print(f"Banner added        : {added}")
    print(f"Already has banner  : {skipped_has_banner}")
    print(f"No insertion point  : {skipped_no_anchor}")
    if DRY_RUN:
        print("DRY RUN — no files written. Set DRY_RUN = False to apply.")


if __name__ == "__main__":
    main()
