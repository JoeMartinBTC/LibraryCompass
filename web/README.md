# web/ — product page for librarycompass.com

Static page, live at <https://librarycompass.com>. No build step: what is in this folder
is what gets served.

## Files

| Path | Purpose |
|---|---|
| `index.html` | the whole page — markup, CSS and JS inline, no external requests |
| `img/*.webp` | screenshots, 1800 px wide, quality 82 |
| `robots.txt` | allows AI crawlers explicitly, points at the sitemap |
| `sitemap.xml` | one URL; also the input for the server's `gen-llms.py` |

**No external dependencies on purpose** — no web fonts, no CDN, no analytics. Nothing
leaves the visitor's browser, which keeps the page GDPR-uncomplicated and matches the
design handoff (`design/handoff/README.md` §9).

## Language and appearance

The German text lives in the markup; the English translation is a JS object keyed by
`data-i18n`. Both toggles persist in `localStorage`, and both accept a deep link:

    https://librarycompass.com/?lang=en&theme=light

The appearance toggle also swaps the screenshots — but only for grid, list and zoom,
where both variants exist. Detail and ISBN are light-only and stay put (see `BOTH` in
the script).

## Screenshots

They show the author's own library, published deliberately. Book covers and titles
belong to their publishers and appear purely to illustrate the software.

To take fresh ones instead, the app writes window snapshots from a **demo** library — the
real store is never opened in that mode:

    ./LibraryCompass.app/Contents/MacOS/LibraryCompass \
      --screenshot <path> [--appearance hell|dunkel] [--state list|detail|isbn|import]

Then scale and convert in one step (`sips` cannot write inside a sandbox, `cwebp` can):

    cwebp -q 82 -resize 1800 0 <shot>.png -o img/<name>.webp

Keep the `width`/`height` attributes in `index.html` in sync with the real pixel sizes,
or the page will jump while loading.

## Deploy

The page is plain static files — any web server that can serve a directory works.
Sync the contents of `web/` to the server's web root, make them world-readable, done:

    rsync -avz --delete web/ <deploy-target>:<webroot>/

Server details, access and safety rules are documented privately and are deliberately
not part of this repository.
