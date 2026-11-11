# web/ — librarycompass.com

Static pages, live at <https://librarycompass.com>. No build step: what is in this folder
is what gets served. Besides the LibraryCompass product page the site hosts the pages of
four other private hobby projects by the same author.

## Files

| Path | Purpose |
|---|---|
| `index.html` | the LibraryCompass page — markup, CSS and JS inline, no external requests |
| `img/*.webp` | LibraryCompass screenshots, 1800 px wide, quality 82 |
| `bitcoin-uhr/` | page of the Bitcoin Clock (<https://github.com/JoeMartinBTC/Bitcoin_clock>) |
| `bitcoin-pointcloud/` | page of the Bitcoin Point Cloud (<https://github.com/JoeMartinBTC/bitcoin-pointcloud>) |
| `bitcoin-pointcloud/demo/index.html` | unmodified copy of the point cloud's `index.html`, embedded live on its page |
| `goals/` | page of Goals (<https://github.com/JoeMartinBTC/goals>) |
| `fun-watch/` | page of Fun Watch (<https://github.com/JoeMartinBTC/fun_watch>) |
| `robots.txt` | allows AI crawlers explicitly, points at the sitemap |
| `sitemap.xml` | all five pages; also the input for the server's `gen-llms.py` |

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

## Sub-pages and the shared footer

All five pages share one look: the subpages copy the complete `<style>` block of
`index.html` and add a few rules of their own at the end. Language and theme toggles work
the same way and share the `localStorage` keys `lc-lang` and `lc-theme`.

Every page ends with the same **“Projekte” column** in the footer: LibraryCompass, Bitcoin
Clock, Bitcoin Point Cloud, Goals and Fun Watch, each with a one-line description (`data-i18n="proj.*"`,
English strings in the page's script). The current page is marked with
`aria-current="page"`. **Adding a project means adding it to this block on every page**
and adding its URL to `sitemap.xml`.

### Bitcoin Clock (`bitcoin-uhr/`)

Images are renderings from the app's snapshot mode with a transparent background
(`BitcoinUhr --snapshot <dir> 21:45:20 10:12:00`), converted with
`cwebp -q 84 -resize 1000 0`. The 24 formulas in the grid were checked to round to their
hour when the page was built.

### Bitcoin Point Cloud (`bitcoin-pointcloud/`)

The live demo is an `<iframe>` pointing at `demo/?v=2`, served from this site, so the page
makes no third-party requests. When the point cloud's `index.html` changes upstream, copy
it into `demo/` again and raise the `?v=` number so browsers do not keep an old copy.

- **The demo must be allowed in a frame.** If the server sends `X-Frame-Options: DENY`
  for the whole site, the frame stays empty. Allow framing *by the same site only*
  (`SAMEORIGIN`) for `/bitcoin-pointcloud/demo/*` and keep `DENY` everywhere else.
- Below 700 px the frame is hidden: the demo's settings panel would cover the whole cloud.
  Only the “open full window” button remains.
- The canvas only contains the specks; the paper colour is the demo page's CSS
  background. Exported screenshots are therefore transparent and need the paper colour
  `#ece2cd` put behind them before converting.

### Goals (`goals/`)

Images come from the app's snapshot mode, which writes them to the folder `seite/`
(`Goals --snapshot <dir>`). The six goals on the goal displays are made-up examples.

- Images of the goal displays have a transparent background and exist per language
  (`cwebp -q 84 -resize 2000 0` for `hero-*`, `-resize 1300 0` for `karten-*`). The script
  swaps them when the language changes. The hero image also changes with the appearance:
  Polarlicht on dark, Morgenrot on light. Below 700 px it uses the two-column `karten-*`
  version, because three columns would be unreadable on a phone.
- The settings window has no background of its own in the snapshot. Put the window colour
  behind it before converting: `magick <in> -background '#26232d' -flatten <out>` for dark,
  `#f2f0f6` for light, then `cwebp -q 84 -resize 1500 0`.

### Fun Watch (`fun-watch/`)

Images are strips from the app's still mode, four clocks side by side
(`Zeigerreiter --bogen <file.png> HH:mm:pose:colour:dial:figure:language[:k|btc]`),
converted with `cwebp -q 86`. Only `bewegungen-*` exists per language; the other strips
mix languages on purpose. The Bitcoin values in the pictures are fixed examples.

The demo film (`film/vorfuehrung-{de,en}.mp4`, 800×1200, 40 s, about 380 KB each) is
rendered frame by frame with `Zeigerreiter --film <dir> salbei:schlicht:mensch:<lang>`
and encoded with H.264 `-crf 28 -preset slow` (VP9 `-crf 36` came out larger: 636 vs
384 KB). It plays `autoplay muted loop playsinline controls`; the script swaps source and
poster with the language. The frames have transparent rounded corners, which turn black
in the video, so the `<video>` gets `border-radius: 7% / 4.667%` to clip them.

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

    rsync -avzc --exclude README.md web/ <deploy-target>:<webroot>/

⚠️ `--exclude README.md`, sonst landet diese Datei im Web-Root und ist öffentlich
abrufbar. Am 2026-08-10 genau so passiert und sofort wieder entfernt.

⚠️ **Kein `--delete`.** Im Web-Root liegen Dateien, die nicht aus diesem Ordner
stammen (z. B. der geschützte Live-Viewer). `--delete` würde sie löschen. `-c`
vergleicht per Prüfsumme, damit nur wirklich geänderte Dateien übertragen werden.

After deploying, regenerate the server's `llms.txt`/`llms-full.txt` so new pages appear
there too.

Server details, access and safety rules are documented privately and are deliberately
not part of this repository.
