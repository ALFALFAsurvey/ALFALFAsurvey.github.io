# ALFALFAsurvey.github.io
This is the repository containing the ALFALFA survey legacy website. The main site can be accessed at: https://alfalfasurvey.github.io/

The purpose of the website is to:
1) have one landing place for all ALFALFA Legacy information, collecting links from a range of historical ALFALFA websites.
2) create an archive of ALFALFA wisdom.

Note that github limits sites to 1GB, so large files will be held separately on a google drive and linked from this site.

If you have ideas for updating the site, please create an issue/ branch, and then merge in your updates with a pull request when ready.

---

## Archival Site (`rwebhtml/`)

The `rwebhtml/` folder contains a static HTML archive of the original ALFALFA rweb PHP site, converted for hosting on GitHub Pages. Large data files (PDFs, FITS, CSVs, etc.) are stored on Google Drive and linked directly from the HTML pages; only small files (HTML, CSS, text, images under 100 KB) live in this repository.

### Conversion workflow

The archive was built in two phases:

**Phase 1 — `convert_alfalfa.py`**

Converts the original PHP source tree (from a local copy of the rweb archive) into a static HTML site:
- PHP files that include `bannermenu.php` (in any form — bare, relative `../`, or absolute URL) have the banner replaced with inlined HTML and are renamed `.html`
- PHP files with no PHP content are renamed `.html` as-is
- All other files are copied unchanged
- A second pass rewrites internal `.php` links to `.html`

Run with `DRY_RUN = True` (the default) to preview actions, then set `DRY_RUN = False` to write files.

**Phase 1b — `fix_cornell_links.py`**

Rewrites all `http://egg.astro.cornell.edu/alfalfa/PATH` links in `rwebhtml/` and `aweb/` HTML files:
- Path exists in `rwebhtml/` → relative link
- Path found in `drive_url_map.json` → Google Drive URL
- Neither → original Cornell URL left unchanged (logged)

**Phase 1c — `fix_naic_links.py`**

Rewrites all `http://www.naic.edu/~a2010/PATH` (and `%7Ea2010` URL-encoded variant) links in `aweb/` and `rwebhtml/` HTML files:
- Path exists in `aweb/` → relative link (computed per source file, works across directories)
- Path not found → original NAIC URL left unchanged (logged)

Other NAIC URLs (e.g. `alfa.naic.edu`, `~cima`, `~phil`) are not touched by this script.

**Phase 2 — `gdrive_sort.py`**

Trims `rwebhtml/` to fit within GitHub's size limits and rewrites links to point to Google Drive:
- Files with large/data extensions (`.pdf`, `.fits`, `.csv`, `.ppt`, etc.) or over 100 KB are deleted from `rwebhtml/` — they stay on Google Drive
- Small files (HTML, CSS, small text/images) stay in `rwebhtml/` and are removed from Drive
- Junk files (`.DS_Store`, editor backups `*~`) are deleted from both places
- Links in all HTML files are rewritten to point to the Google Drive sharing URLs
- Progress is saved incrementally to `drive_url_map.json` so the script is safe to interrupt and resume

Again, run with `DRY_RUN = True` to preview, then `DRY_RUN = False` to apply.

**Utility — `test_drive.py`**

A small helper script for verifying Google Drive API connectivity and OAuth credentials before running `gdrive_sort.py`. Run it first if you're setting up credentials on a new machine.

**Link checker — `check_wayback.py`**

Scans all HTML files in the repo for external links, checks whether each is currently live, and for dead links checks the Wayback Machine for an archived snapshot. Output is saved to `wayback_results.tsv`.

```
python check_wayback.py                    # scan all external URLs
python check_wayback.py --naic-only        # NAIC URLs only
python check_wayback.py --recheck-errors   # retry rows that previously errored (longer timeout)
python check_wayback.py --recheck-wayback  # re-query Wayback for all DEAD+YES rows to get
                                           # the most recent snapshot instead of oldest
```

The TSV has columns: `url | live | wayback | wayback_url | wayback_timestamp`. Runs can be interrupted and resumed — already-completed rows are skipped on re-run. If `--recheck-wayback` is interrupted mid-run, no data is lost (original snapshots are preserved in the TSV as a safety net). If any re-queries error out, the old snapshot is kept and the affected URLs are written to `wayback_fallbacks.txt`; re-running `--recheck-wayback` will retry only those.

**Dead-link fixer — `fix_wayback_links.py`**

Reads `wayback_results.tsv` and fixes broken links across all HTML files:
- `DEAD + YES wayback` → URL replaced with the Wayback archive snapshot
- `DEAD + NO wayback` → listed in `dead_links_report.txt` for manual review

Run with `DRY_RUN = True` (the default) to preview replacements and generate the report, then set `DRY_RUN = False` to apply. Run `check_wayback.py --recheck-wayback` first to ensure snapshots point to the most recent archive rather than the oldest.

---

## Setting up the Google Drive API

To run `gdrive_sort.py` you need to enable the Google Drive API and obtain OAuth credentials.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) and create a new project (the project used here is **ALFALFAwebsite**; direct link: https://console.cloud.google.com/apis/dashboard?project=alfalfawebsite).
2. Under **APIs & Services → Library**, search for **Google Drive API** and enable it.
3. Under **APIs & Services → OAuth consent screen**, configure the consent screen (choose **External**) and follow the prompts.
4. Under **APIs & Services → Credentials**, click **+ Create Credentials → OAuth client ID**. Set the application type to **Desktop App** and download the resulting JSON file.
5. Save the downloaded JSON as the filename referenced by `CREDS_FILE` in `gdrive_sort.py` (do not commit this file — it contains your client secret).
6. Install the required Python packages:

   ```bash
   pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
   ```

   Or with conda:

   ```bash
   conda install -c conda-forge google-api-python-client google-auth-httplib2 google-auth-oauthlib
   ```

7. On first run, a browser window will open for OAuth authorization. After completing it, a `token.json` file is saved locally for future runs (do not commit this file either).
