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
rsync -avz --delete --exclude README.md viewer/ -e "ssh -i <key>" <target>:<webroot>/<secret-path>/
```

⚠️ `--exclude README.md`, sonst liegt diese Datei im Web-Root und beschreibt Fremden den
Aufbau. Am 2026-08-10 zweimal passiert — hier und bei `web/` — und beide Male sofort
wieder entfernt.

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
### The scanner reads the barcode itself

`BarcodeDetector` is missing exactly where this page is used: Safari has it **off by
default** through version 26, Firefox does not have it at all. On the iPhone the scan
button therefore never appeared — the first version tied it to that API.

So `ean.js` decodes EAN-13 on its own: image row → light/dark run lengths → digits by
pattern match → first digit from the parity pattern → check digit. About 240 lines,
no dependency, works offline. A ready-made library would have been 400 KB of foreign
code and a runtime dependency, against this page's whole premise.

Three guards stand between a camera frame and an answer, and each one was earned:

- **Check digit** — the obvious one.
- **Width consistency**: the runs from start to end must add up to 95 × module width.
  Without it, random noise assembled a code that passed the check digit.
- **Three agreeing rows, and a minimum module width of 1.6 px.** Two rows still let noise
  through: `9511145768041` came out of five different random images. A real barcode in a
  camera frame is coarser than that; below it the book is simply too far away.

Run the tests with `node viewer/ean.test.mjs` — 58 cases: five codes across module widths
2 to 6, noise up to ±70, blur, inverted print, narrow quiet zones, plus 40 rounds of pure
noise that must yield nothing.

An invented number is the worst outcome here: it answers „do I already own this?" with a
different book.
