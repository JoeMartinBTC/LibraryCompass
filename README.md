# LibraryCompass

Simple native macOS app to catalog physical books: scan/enter ISBN, fetch freely
available metadata (title, author, cover), add personal star rating, comment, and
read date. Deliberately minimal — a stripped-down successor to Delicious Library
for personal use.

## Scope (Phase 1 — Mac only)

- Import module for Delicious Library plist XML export (~1,780 books)
- Book list with cover, title, author, own rating, own comment, read date
- Add books by ISBN (manual entry), metadata via Open Library / Google Books
- Local persistence, no account, no server

Out of scope for now: iPhone app, sync, barcode camera scan.

## Status

Phase 1 built. `./make-app.sh` builds the bundle, `./install-app.sh` puts it into
`/Applications`, `swift test` runs the suite.

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
| `Sources/LibraryCompassCore/` | model, store, import, query, stats, lookup, cover cache |
| `Sources/LibraryCompass/` | SwiftUI app: views, design tokens, app model |
| `Tests/LibraryCompassTests/` | 108 tests, including live network checks |
| `UITests/` | XCUI smoke tests (`./ui-test.sh`) |
| `docs/` | lookup strategy, Google Books key setup |
| `make-app.sh` / `install-app.sh` | build the bundle, install to `/Applications` |

Data lives in `~/Library/Application Support/LibraryCompass/` (SwiftData store,
cover cache, API key) — never in the repo.
