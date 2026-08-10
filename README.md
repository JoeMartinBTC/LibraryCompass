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

## Using the app

The interface is German; the labels below are quoted exactly as they appear on screen.
Nothing here needs an account, and nothing leaves the machine except the catalogue
queries that fetch a title or a cover.

### The window

| Where | What sits there |
|---|---|
| **Left — sidebar** | The four views of the stock (*Alle Bücher · Gelesen · Ungelesen · Bewertet*) with their counts, the *Lücken* basket once it has content, the **„Buch hinzufügen"** button, and **„Delicious Library importieren"** at the very bottom. Drag its right edge to resize it; the toolbar's left icon hides it — then „Buch hinzufügen" returns as a floating button over the covers |
| **Middle** | Search, zoom, sort, grid/list toggle and the light/dark switch on top; below them the heading, the count line and the statistics cards (*„Statistik"* folds them away); then the books, loaded in blocks of 60 as you scroll |
| **Right — „Details"** | Appears when you click a book. Cover, title, author, year and pages, the author-bibliography button, your rating, read date and comment, the ISBN, and *„Buch löschen"* |

### Everyday tasks

| You want to … | Do this |
|---|---|
| **Add a book by barcode** | ⌘K, hold the barcode 25–40 cm from the camera until it is sharp. Scanned titles are listed as they arrive; *„Fertig"* closes the sheet. An iPhone as Continuity Camera focuses far better than the built-in one |
| **Add a book by ISBN** | ⌘N, type or paste the ISBN — a copied Amazon product URL works too. Title, author, year, pages and cover are fetched for you |
| **Add a book that has no ISBN** | Same dialog. If the input is not an ISBN (or is an Amazon ASIN), the sheet says so and asks for title and author instead. The author is required — without it no cover can ever be found for that entry |
| **Rate a book** | Click a star in the detail panel; *„zurücksetzen"* clears the rating. Saved instantly, no OK button anywhere |
| **Record when you read it** | *„Gelesen am"* — pick a date, or hit *„Heute"* |
| **Write a note** | The *„Kommentar"* field. Saved as you type |
| **Find a book** | The search field matches title *and* author, any part of the word. The clear button is the ✕ inside the field |
| **Sort** | The toolbar menu: *Titel A–Z · Autor A–Z · Erscheinungsjahr, neueste zuerst · Bewertung, beste zuerst · Zuletzt gelesen · Zuletzt hinzugefügt · Ohne Cover zuerst.* The last one pulls everything still missing artwork to the front so it can be worked through in one pass |
| **See more or fewer covers at once** | The zoom control, 70–170 % in steps of ten |
| **Delete a book** | *„Buch löschen"*, then confirm — the dialog names the title, because this is the one step nothing undoes. Rating and comment go with it; the cover file stays on disk, since two entries may share one picture |
| **Get everything out** | ⌘E writes a CSV with all ten fields (RFC 4180 with BOM, so Excel shows the umlauts) |
| **Mark a whole shelf as read** | *Ablage → „Alle als gelesen markieren"* gives every book without a read date the date it was added |

### A cover the app could not find

For older German editions and self-published titles, no source a program is allowed to
query carries a picture — but a person can see it in their browser. So the detail panel
takes it from you, three ways:

1. **Drag** an image from a browser onto the cover — a frame and *„Bild hier ablegen"* mark the target
2. **„Einfügen"** takes the picture from the clipboard
3. **„Suchen"** opens title and author as a book search in your own browser, so you can go and find one

A picture you assign by hand always wins over the automatic passes, and it stays assigned:
withdrawing a wrong cover is remembered, so the next backfill will not fetch it again.

### „Autorbibliografie" — what else did this author write?

The button in the detail panel asks the German National Library for the author's works,
matches them against your shelf, and puts what is missing into the **„Lücken"** basket in
the sidebar, with covers.

- Gaps are **counted separately and never join the stock** — not in the counts, not in the
  CSV export, not in the statistics. They are stored as their own kind of record
- Only German print editions count. Audiobooks, e-books, translations and editions of a
  book you already own are filtered out — [docs/bibliografie.md](docs/bibliografie.md)
  lists the case behind each of those rules
- Remove one gap with the ✕ on its cover; empty the whole basket with the wastebasket on
  the *„Lücken"* row. Both leave the stock untouched, and a new run brings the list back
- Running it again for the same author **replaces** that author's gaps, so a book that has
  meanwhile moved onto the shelf drops out by itself

### Keyboard

| Keys | Action |
|---|---|
| ⌘K | Scan a book |
| ⌘N | Add by ISBN |
| ⌘E | Export the library as CSV |

### Where your data lives

`~/Library/Application Support/LibraryCompass/` — the database, the cover cache, and the
optional Google Books key. Never in the repo, never on a server. Back it up like any other
folder; [docs/backup.md](docs/backup.md) describes the restore.

## License

MIT — see [LICENSE](LICENSE).
