# Covers — cache keys, backfill, and the two bugs that shaped both

How a book gets its picture, where that picture is stored, and what the code is
guarding against. The rules here are not preferences; each one exists because the
opposite was tried on a real 1,780-book library and produced visible damage.

Where covers come *from* (Amazon by ISBN-10 first, then the free sources) is a
separate concern, documented in [lookup.md](lookup.md). This file is about what
happens **after** a cover URL is found.

## Where covers live

Files sit in `~/Library/Application Support/LibraryCompass/Covers/`, next to the
SwiftData store and outside the repository. The model holds only a file name in
`Book.coverPath`; `nil` or empty means "no picture yet", which is also the flag the
backfill selects on.

An image under **1,500 bytes** is not an image. Open Library answers with a 1×1
pixel instead of a 404, and Amazon answers a genuine miss with 43 bytes. Both slip
past a naive `status == 200` check, so `CoverCache.isUsableImage` gates every write.

Size only proves an image *exists*, though — not that it belongs to this book. Two
books once ended up with byte-identical covers: the HarperCollins placeholder
"COVER TO BE REVEALED", a perfectly valid 15,419-byte JPEG. The guard against that
is not a list of known placeholders (every publisher has one) but a rule:
**the same image is never handed to two different books.** `CoverCache` keeps a
checksum→stem index, built on first use from the files already on disk, and rejects
an image that already belongs to someone else.

That costs the occasional cover when two editions genuinely share artwork. It is the
right trade: a missing cover reads as a gap, a wrong one reads as a broken program.

## The cache key: `CoverKey.stem`

```swift
CoverKey.stem(isbn: String, title: String, author: String) -> String?
```

- Book **has an ISBN** → the normalized ISBN is the stem. Names stay readable, and a
  second run lands on the same file instead of duplicating it.
- Book has **no ISBN** (~235 of the imported stock) → a stable **FNV-1a 64-bit hash**
  over folded title + author, prefixed `t-`.
- Neither ISBN nor title → `nil`. There is nothing to key on, so nothing is stored.

Three deliberate choices, each with a failure behind it:

**Optional, never empty string.** The function may fail, and failure has to be
loud. An empty stem is not a harmless edge case — it makes every affected book point
at the *same* file. `CoverCache.download` re-checks `!stem.isEmpty` at the write site
rather than trusting its caller.

**Hash, not `UUID()`.** The backfill runs repeatedly over the same library. A random
identifier mints a fresh file on every pass and abandons the previous one, so the
cache grows without bound while nothing improves.

**Self-rolled FNV-1a, not `hashValue`.** Swift seeds `Hashable` per process. Its
output is stable within one run and different in the next — the one property a file
name must never have.

## Bug 1: 54 books shared two files

Before `CoverKey` existed, the backfill passed the **title** into the `isbn` parameter
when a book had no ISBN. That value then ran through the ISBN normalizer:

```swift
// correct for ISBNs, catastrophic for titles
raw.uppercased().filter { $0.isNumber || $0 == "X" }
```

"All the Devils" contains no digit, so the stem was `""` and the file was named
`.jpg`. Measured on the real library: **50 books on `.jpg`, 4 on `X.jpg`** (titles
containing exactly one X). Last download wins, so a single cover appeared on dozens of
unrelated books.

Both calls type-checked — ISBN and title are both `String`. The lesson generalizes past
this codebase: **a normalizer belongs to its field**, and any function deriving a key
from user data must be able to return `nil` instead of collapsing to a constant.

The invariant is now a test, not a one-time cleanup. `CoverCollisionTests` runs two
ISBN-less books through the real backfill and asserts their paths differ.

## Bug 2: a run that stopped at 1,188 of 1,780 and reported success

The first full backfill quit two thirds of the way through and exited 0. Nearly 600
books were never asked about, and nothing said so.

It surfaced by bucketing hit rate along processing order:

```sql
select (Z_PK/100)*100 block, count(*) total,
       sum(case when ZCOVERPATH is not null and ZCOVERPATH<>'' then 1 else 0 end) with_cover
from ZBOOK group by block order by block;
```

Through block 1100 the rate sat between 76 % and 92 %. From block 1200 on it was
**0.0 % across six consecutive blocks**. A rate that drops vertically to zero is not a
source problem — sources degrade, they do not stop dead on a boundary. That shape means
the process died.

The likely trigger: the maintenance run keeps no window, and macOS terminates an app
when its last window closes. Four defenses now:

- `Report` carries `total` alongside `checked`, with `isComplete`.
- An incomplete summary reads `ABBRUCH — geprüft=1188/1780 …` instead of a number that
  looks fine in isolation.
- `--fetch-covers` exits **1** when the run did not finish.
- `Task.checkCancellation()` in the loop, and
  `applicationShouldTerminateAfterLastWindowClosed` returns `false` during the run.

**`geprüft=n` alone is not a completeness claim.** Only `n/total`, backed by an exit
code, is one.

## Running the backfill

The app must be closed first — the maintenance process opens the same SwiftData store:

```bash
pgrep -f "LibraryCompass.app/Contents/MacOS"   # must print nothing
./LibraryCompass.app/Contents/MacOS/LibraryCompass --fetch-covers
echo $?                                        # 0 = complete, 1 = aborted
```

It only visits books whose `coverPath` is empty, so it resumes naturally: re-run it
until the filled count stops rising. It is sequential with a one-second pause on
purpose — Google throttles anonymous access per day, and a burst of parallel requests
buys nothing but 429s.

Afterwards, wait for the process to exit before launching the GUI. `open -a` on a
running bundle **activates the existing instance** rather than starting a new one, so
opening the app during a run just foregrounds a windowless process and looks like an
app that refuses to show anything.

## Verifying the result

These check the data, not the app's opinion of itself.

```bash
DB=~/Library/Application\ Support/LibraryCompass/Library.store

# no two books may share a file — must return 0
sqlite3 "$DB" "select count(*) from (select ZCOVERPATH c, count(*) n from ZBOOK
  where ZCOVERPATH is not null and ZCOVERPATH<>'' group by c having n>1);"

# coverage
sqlite3 "$DB" "select count(*) from ZBOOK where ZCOVERPATH is not null and ZCOVERPATH<>'';"
```

Three further checks worth running after a large import: every `coverPath` resolves to a
file of at least 1,500 bytes; every book *with* an ISBN carries an ISBN-derived stem; and
no two cover files are byte-identical. The first two should come back zero. The third may
legitimately report a pair when the same book is catalogued twice — that happens, and the
entries are not duplicates to be merged.

A stem that does not match its book's ISBN means the cover was fetched over the fuzzy
title search *before* the book had an ISBN. Those are worth clearing so the next run
fetches the edition-exact image instead:

```bash
sqlite3 "$DB" "update ZBOOK set ZCOVERPATH=null
  where ZISBN<>'' and ZCOVERPATH like 't-%';"
```

Cover files that no book points at are leftovers from earlier runs and can be deleted;
compare the directory listing against the `coverPath` values.

## Filling in missing ISBNs first

A book with no ISBN cannot reach the only edition-exact cover source, so the largest
remaining gap is a *data* gap rather than an image one. `--fetch-isbns` closes it where
the German National Library can vouch for the book:

```bash
./LibraryCompass.app/Contents/MacOS/LibraryCompass --fetch-isbns   # then --fetch-covers
```

It searches `TIT=<title> and PER=<surname>`, and adopts an ISBN **only** from a record
whose `[Verfasser]` matches the stored author. Everything else is rejected: a translator
or narrator credit is not proof of authorship, and a search for a title regularly returns
the audiobook box alongside the novel. A wrong ISBN is worse than none — it corrupts the
data *and* pulls the wrong cover — so the check digit is validated too, and `urn:nbn:…`
identifiers are ignored.

Only the DNB is queried here. Google Books runs out of its daily quota after a large
backfill (`429 … Queries per day`), and Open Library covers German editions poorly.

This is a separate pass from the cover backfill on purpose. A missing ISBN and a missing
picture are different gaps, each worth repeating on its own — the same reason metadata
hits and cover hits were decoupled earlier.

## What is legitimately missing

Not every gap is a defect.

- **979-prefix ISBNs** have no ISBN-10 equivalent, so the edition-exact Amazon endpoint
  cannot be queried at all.
- **Books without an author** can use neither the ISBN lookup nor the title search, because
  the author match is what keeps both from attaching a wrong edition. Dropping that guard
  once produced an English cover for a German edition.
- Some older German editions simply are not carried by any free source.

A missing cover is honest. A wrong one is not, which is why every fallback stage is
guarded and no stage is allowed to guess.

## Assigning a checked cover by hand

The automatic pass decides on its own and is sometimes wrong. On 2026-08-09 it fetched
seven covers and three of them showed a different work — visible only by looking at the
pictures, never in the counters. So the last stage of the chain is a person, and that
person needs a way into the store:

```bash
LibraryCompass --apply-covers assignment.tsv
```

One line per book, tab separated. The key is the entry's ISBN, or — for books without one
— the title hash from `CoverKey.stem`. An empty second field withdraws a wrong cover:

```
9783958905733	/path/to/checked.jpg     ← set this cover
3893170065	                             ← remove the cover
```

The same guards apply as in the automatic pass: minimum size, and the placeholder guard
that refuses to give one image to two different books. A key that matches no book, or more
than one, is skipped and the run reports `ABBRUCH` with exit 1 — it never guesses which
book was meant.

The image file of a withdrawn cover stays on disk. The library holds duplicates of the
same book, two entries can share one picture, and deleting it would strip the cover from
the entry that kept it.

## Two limits found on 2026-08-09

**A sibling edition is not reachable from the stored ISBN.** „Wie man einen Drachen tötet"
was stored under the audiobook's ISBN; the print edition has a different one, and the DNB
does not link the two records. Only a **title search** (`tit=` plus `per=`, or K10plus,
or Open Library) finds the siblings, and each sibling brings its own ISBN to try.

**The Amazon ISBN endpoint is not always edition-exact.** Under the correct ISBN
`3548229077` („Depesche aus dem Jenseits", Ullstein) it serves the cover of a different
volume in the same series. The endpoint remains first choice, but its answer is evidence,
not proof — which is what the human check is for.

## Sibling editions — the stage that was missing

The stored ISBN names **one edition**; the cover belongs to the **work**. If the entry
carries the audiobook's or the e-book's ISBN, Amazon serves no picture under it, while the
print edition — a different ISBN — has one.

The two catalogue records are **not linked**. „Wie man einen Drachen tötet" is stored as
`9783863526191` (Hierax Medien, a reading, 43 bytes at Amazon); the Europa Verlag print run
is `3958905730` and serves 22.606 bytes. The print record's `776` field points only at the
online edition, never at the reading. Nothing leads from one ISBN to the other.

Only a **search by title and author** finds the siblings, and each sibling brings its own
ISBN to try at the image endpoint. `siblingISBNs` does that, with both guards moved:

- **Title stricter.** `sameWork` compares the **unabridged** title of the entry, not the
  simplified search form. „Steve Jobs" is a prefix of two different books by Jeffrey Young,
  and the loose comparison handed the entry the wrong one on 2026-08-09.
- **Author looser.** The DNB was already queried with `PER=`, so it matched the person
  itself — and it transliterates differently than the library does. „Chodorkowski" against
  „Chodorkovskij" fails a word-by-word comparison; `sameSurname` asks for six shared leading
  characters and a length difference of at most two.

Without an author on the entry there is no sibling search at all. The anchor is missing,
and „Flashback" alone returns nine different books.

## Withdrawn covers stay withdrawn

Three wrong covers were withdrawn by hand on 2026-08-09. The next `--fetch-covers`, the
following morning, fetched two of them back — the chain finds the same source again. A
correction the next run undoes is not a correction.

`Covers/abgelehnte-cover.tsv` records `identity <TAB> sha256` for every image a person
rejected for a given book. Both ways into the cache check it. The entry is written by
`--apply-covers` itself when it clears a cover, because a rule you have to remember to
maintain by hand is a rule that gets forgotten.

The rejection binds an **image to a book**, not a book. Assigning a different — correct —
cover to the same book stays possible, which is the whole point of withdrawing the wrong one.

## The manual path — when a person may look and a program may not

96 books have no cover at any source the app is allowed to query: older German editions no
free catalogue ever recorded, and self-published titles without an ISBN-10. The pictures do
exist — `amazon.de/robots.txt` simply rules out automated access, and names Claude agents
explicitly:

```
User-agent: ClaudeBot
Disallow: /
```

That rule binds the program, not its user. Someone searching for their own books is not a
bot. So the app stops pretending the picture does not exist and takes it from them instead:

- **Drop an image onto the cover** in the detail panel — from the browser, the Finder, or
  as a plain URL. The app handles all three, because which one arrives is the browser's
  decision, not the app's.
- **Paste** from the clipboard. A file URL is preferred over `NSImage`: the latter is often
  the downscaled screen version.
- **Search** opens title and author as a book search in the user's own browser. One click
  instead of typing.

### A hand-assigned cover overrides the guards

`store(…, trusted: true)` skips the duplicate guard and the rejection list. Both replace a
judgement that is already present here: the duplicate guard infers from *suspicion* that two
identical images are a publisher placeholder, and the rejection list records an earlier
automatic mistake. Someone looking at the cover knows better than either. An existing
rejection for that book is lifted rather than merely bypassed — otherwise it would strike
again on the next run.

The minimum size still applies. A 43-byte no-answer is not an image no matter who assigns
it, and dragging from a browser produces exactly that often enough.
