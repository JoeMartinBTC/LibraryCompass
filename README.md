# LibraryCompass

Simple native macOS app to catalog physical books: scan or enter an ISBN, fetch
freely available metadata (title, author, cover), add a personal star rating,
comment, and read date. Deliberately minimal — a stripped-down successor to
Delicious Library for personal use.

## Features (Phase 1 — Mac only)

- **Barcode scanning** via camera (⌘K) — EAN-13/ISBN with check-digit validation,
  iPhone works as a Continuity Camera and is preferred for its autofocus.
  Details and pitfalls: **[docs/scanner.md](docs/scanner.md)**
- **Add by ISBN** (⌘N), metadata via Open Library → DNB → Google Books,
  covers from Amazon by ISBN-10 first: **[docs/lookup.md](docs/lookup.md)**.
  An Amazon ASIN or a pasted product URL is recognised as such — it is not an ISBN, and
  turning it into one used to produce a phantom number. Books without an ISBN (e-books,
  self-published titles) are created from title and author instead
- **Delete an entry** — with a confirmation naming the title. The cover file stays: the
  library holds duplicates, and two entries can share one picture
- **Cover cache and backfill** — one file per book, resumable, an incomplete run
  says so and exits non-zero: **[docs/covers.md](docs/covers.md)**
- **Pocket viewer** — `--export-web` writes the stock as a small offline page: search,
  barcode scan, and one answer — do I already own this? It decodes EAN-13 itself, because
  `BarcodeDetector` is off by default in Safari and absent in Firefox — exactly the
  browsers this gets used in. Built for the bookshop, not for editing:
  **[viewer/README.md](viewer/README.md)**
- **Set a cover by hand** — drop an image onto the cover in the detail panel, paste it,
  or hit *Suchen* to open title and author as a book search in your own browser. For older
  German editions and self-published titles no free source carries a picture, so the app
  takes it from you instead of pretending none exists
- **Author bibliography** — one button in the detail panel pulls the author's works from
  the DNB, matches them against the shelf, and puts what is missing into its own basket
  with covers. Counted separately and stored as its own type, so a gap can never slip into
  the stock, the CSV export, or the stats: **[docs/bibliografie.md](docs/bibliografie.md)**
- **Import** of the Delicious Library plist XML export — idempotent, keeps own
  ratings/comments, marks imported books as read (added date = read date),
  strips catalog clutter from titles ("Wer Lügen sät: Thriller" → "Wer Lügen sät")
- **CSV export** (⌘E) — all ten fields, RFC 4180 with BOM so Excel shows umlauts
- Library UI: grid/list, search, filters, stats cards, zoom, light/dark. Sort by title,
  author, publication year, rating, last read, **last added**, or **"Ohne Cover zuerst"**,
  which pulls the books still missing artwork to the top so they can be worked through
  in one pass
- Local persistence (SwiftData), no account, no server

Out of scope for now: iPhone app, sync.

## Build & install

```bash
./make-app.sh      # build the .app bundle (SwiftPM release + ad-hoc signing)
./install-app.sh   # install to /Applications (resets the TCC camera grant — see docs/scanner.md)
swift test         # the full suite, including live network checks
./ui-test.sh       # XCUI smoke tests via xcodegen project
```

Headless maintenance (app must be closed — same SwiftData store):

```bash
LC=./LibraryCompass.app/Contents/MacOS/LibraryCompass

$LC --fetch-isbns              # look up missing ISBNs (DNB)
$LC --fetch-authors            # fill in missing authors, only where the catalogue is unambiguous
$LC --fetch-covers             # backfill covers
$LC --apply-covers list.tsv    # set checked covers by hand, empty field withdraws one
$LC --apply-authors list.tsv   # set or clear authors
$LC --export-web viewer        # catalogue + thumbnails for the pocket viewer
$LC --mark-read                # read date := added date
$LC --export ~/books.csv       # CSV export
```

Order matters: `--fetch-authors` before `--fetch-isbns` before `--fetch-covers`. Without an
author the title search has no anchor and must not run at all; without an ISBN a book cannot
reach the edition-exact cover source. Each pass only visits books with the respective gap, so
they resume on re-run, and each exits **1** when it did not get through the whole list —
check the code, don't trust the last printed line.

The two `--apply-*` passes take a tab-separated file: key, tab, value. The key is the book's
ISBN or its title hash; an empty value withdraws the cover or clears the author. They exist
because an automatic pass sometimes gets it wrong, and a correction needs a way in — and
back. Details: [docs/covers.md](docs/covers.md).

## Metadata sources

Metadata: Open Library → German National Library (DNB, no key, covers German editions
Open Library lacks) → Google Books.

Covers: Amazon by ISBN-10 first — the most edition-exact source, though not infallible: it
has been observed serving another volume of the same series under a correct ISBN. Then Open
Library, Google Books, **sibling editions of the same work found via a catalogue title
search** (the stored ISBN may be the audiobook's, while only the print run carries a
picture), and finally a title search guarded by an author match.

Withdrawn covers stay withdrawn: `Covers/abgelehnte-cover.tsv` records which image was
rejected for which book, so the next backfill does not fetch it again. A cover you assign
by hand overrides that — you looked at it.

Full details, including the pitfalls each step exists for:
**[docs/lookup.md](docs/lookup.md)**.

Google throttles anonymous access per day. To lift that, see
[docs/google-books-key.md](docs/google-books-key.md) and run `./set-google-key.sh <key>`.
The key lives outside the repo, next to the library database.

## Layout

| Path | Purpose |
|---|---|
| `Sources/LibraryCompassCore/` | model, store, import/export, query, stats, lookup, cover cache, scan/title logic |
| `Sources/LibraryCompass/` | SwiftUI app: views, design tokens, app model, barcode scanner |
| `Tests/LibraryCompassTests/` | unit tests, including live network checks — `swift test` is the authority, not a number in this file |
| `UITests/` | XCUI smoke tests (`./ui-test.sh`) |
| `docs/` | scanner (camera/TCC pitfalls), lookup strategy, cover cache/backfill, author bibliography & gap basket, backup & restore, Google Books key setup |
| `design/handoff/` | design tokens and the static mockup the UI was built against |
| `web/` | the product page served at librarycompass.com — plain static files, no build step |
| `viewer/` | the library as a phone page: search, barcode scan, offline — see [viewer/README.md](viewer/README.md) |
| `make-app.sh` / `install-app.sh` | build the bundle, install to `/Applications` |

Data lives in `~/Library/Application Support/LibraryCompass/` (SwiftData store,
cover cache, API key) — never in the repo. A scheduled job snapshots the database and
exports a CSV three times a day; see **[docs/backup.md](docs/backup.md)** for the restore
procedure.

## License

MIT — see [LICENSE](LICENSE).
