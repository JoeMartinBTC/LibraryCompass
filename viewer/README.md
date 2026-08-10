# viewer/ — the library in your pocket

One question, asked in a bookshop: **do I already own this?** Nothing else. No editing, no
lookup, no cover fetching — a list, a search field, and a barcode scanner that the browser
already brings along.

A full iOS app would need a way to get the data onto the phone, and that is where the work
would be: CloudKit demands schema changes, and the covers live as files *next to* the store,
which CloudKit does not carry. A page you add to the home screen skips all of it.

## Build it

```bash
./LibraryCompass.app/Contents/MacOS/LibraryCompass --export-web viewer
```

Writes `katalog.json` and `cover/` into this folder. Measured on 1840 books: catalogue
239 KB, covers 1825 files at 31 MB (down from 63 MB — they are scaled to 160 px, which is
plenty for recognising a spine on a phone). A re-run keeps existing thumbnails, so it takes
about eight seconds.

**Neither file belongs in git.** `.gitignore` covers `viewer/katalog.json` and
`viewer/cover/` — the viewer is source, its content is your library.

## Put it online

```bash
rsync -avz --delete viewer/ -e "ssh -i <key>" <target>:<webroot>/<secret-path>/
```

Then open `https://<domain>/<secret-path>/` on the phone and add it to the home screen.
It works offline afterwards: a service worker keeps the shell and the covers, and asks the
network first for the catalogue — an outdated stock is the worst mistake this page can make.

⚠️ **What goes on the server is your actual library**: every title, every rating, whether
you read it. The path is unguessable and the page carries `noindex`, but that is
obscurity, not a lock. Do **not** list the path in `robots.txt` — that would publish it.
For a real lock, put HTTP basic auth in front of the directory.

## What it cannot do

- **Books without an ISBN never answer to the scanner** — 67 of them here. Search by title.
- **A sibling edition carries a different number.** Your entry may hold the audiobook's
  ISBN while you are scanning the print run. The page therefore says „not under this
  number" instead of „not in your library" — a wrong *no* is what makes you buy twice.
- The scan button only appears where the browser has `BarcodeDetector` (Safari on iOS 17+,
  Chrome on Android). Everywhere else the search field still works.
