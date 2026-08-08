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
  covers edition-exact from Amazon by ISBN-10: **[docs/lookup.md](docs/lookup.md)**
- **Cover cache and backfill** — one file per book, resumable, an incomplete run
  says so and exits non-zero: **[docs/covers.md](docs/covers.md)**
- **Import** of the Delicious Library plist XML export — idempotent, keeps own
  ratings/comments, marks imported books as read (added date = read date),
  strips catalog clutter from titles ("Wer Lügen sät: Thriller" → "Wer Lügen sät")
- **CSV export** (⌘E) — all ten fields, RFC 4180 with BOM so Excel shows umlauts
- Library UI: grid/list, search, filters, sort, stats cards, zoom, light/dark
- Local persistence (SwiftData), no account, no server

Out of scope for now: iPhone app, sync.

## Build & install

```bash
./make-app.sh      # build the .app bundle (SwiftPM release + ad-hoc signing)
./install-app.sh   # install to /Applications (resets the TCC camera grant — see docs/scanner.md)
swift test         # 169 tests, including live network checks
./ui-test.sh       # XCUI smoke tests via xcodegen project
```

Headless maintenance (app must be closed — same SwiftData store):

```bash
./LibraryCompass.app/Contents/MacOS/LibraryCompass --fetch-covers        # backfill covers
./LibraryCompass.app/Contents/MacOS/LibraryCompass --mark-read           # read date := added date
./LibraryCompass.app/Contents/MacOS/LibraryCompass --export ~/books.csv  # CSV export
```

`--fetch-covers` only visits books that have no cover yet, so it resumes on re-run.
It exits **1** when it did not get through the whole list — check the code, don't
trust the last printed line. Details: [docs/covers.md](docs/covers.md).

## Metadata sources

Metadata: Open Library → German National Library (DNB, no key, covers German editions
Open Library lacks) → Google Books.

Covers: Amazon by ISBN-10 first — the only edition-exact source — then Open Library,
Google Books, and finally a title search guarded by an author match.

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
| `Tests/LibraryCompassTests/` | 169 tests, including live network checks |
| `UITests/` | XCUI smoke tests (`./ui-test.sh`) |
| `docs/` | scanner (camera/TCC pitfalls), lookup strategy, cover cache/backfill, Google Books key setup |
| `make-app.sh` / `install-app.sh` | build the bundle, install to `/Applications` |

Data lives in `~/Library/Application Support/LibraryCompass/` (SwiftData store,
cover cache, API key) — never in the repo.

## License

MIT — see [LICENSE](LICENSE).
