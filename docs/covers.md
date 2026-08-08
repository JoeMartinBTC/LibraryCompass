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

Two further checks worth running after a large import: every `coverPath` resolves to a
file of at least 1,500 bytes, and every book *with* an ISBN carries an ISBN-derived
stem. Both should come back zero.

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
