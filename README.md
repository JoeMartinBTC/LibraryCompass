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

ISBN lookup asks Open Library first, then the German National Library (DNB, no key
required — it covers German editions Open Library does not), then Google Books.
Covers come from Open Library or Google Books; the DNB serves none.

Google throttles anonymous access per day. To lift that, see
[docs/google-books-key.md](docs/google-books-key.md) and run `./set-google-key.sh <key>`.
The key lives outside the repo, next to the library database.
