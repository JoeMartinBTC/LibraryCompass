# Wie LibraryCompass Buchdaten findet

Alle Angaben unten wurden live geprüft (Stand 2026-08-05). Wo eine Quelle versagt,
steht das echte Verhalten dabei — genau daran scheiterten frühere Fassungen.

## Reihenfolge

Eine ISBN-Eingabe löst diese Kette aus (`MetadataLookup.metadata(isbn:)`):

| Schritt | Quelle | Liefert | Wann |
|---|---|---|---|
| 1 | Open Library | Titel, Autor, Jahr, Seiten, Cover | immer zuerst |
| 2 | Deutsche Nationalbibliothek (SRU) | Titel, Autor, Jahr, Seiten | wenn Titel noch fehlt |
| 3 | Google Books | Titel, Autor, Jahr, Seiten, Cover | wenn Titel noch fehlt |

Danach die Cover-Kette:

| Schritt | Quelle | Wann |
|---|---|---|
| 1 | **Amazon** über ISBN-10 | immer — einzige ausgabegenaue Quelle |
| 2 | Open Library über ISBN | wenn noch kein Bild |
| 3 | Google Books über ISBN | wenn noch kein Bild und Google noch nicht gefragt |
| 4 | Titelsuche mit Autor-Abgleich | letzte Stufe |

## Warum drei Metadatenquellen

**Open Library** kennt deutsche Ausgaben oft nicht. Zu ISBN 9783785728390 („Toxin")
antwortet sie mit `{}`.

**Google Books** drosselt anonyme Zugriffe pro Tag:
`429 Quota exceeded for quota metric 'Queries' and limit 'Queries per day'`.
Der eingebaute Wiederholungsversuch hilft nicht — die Sperre gilt für den ganzen Tag.
Abhilfe: eigener Schlüssel, siehe [google-books-key.md](google-books-key.md).

**Die DNB** hat beide Probleme nicht: kein Schlüssel, keine Tagesquote, und sie führt
jedes in Deutschland erschienene Buch. Sie liefert allerdings **keine Cover**.

### Feldkunde DNB (`oai_dc`)

- `dc:title` enthält die Verfasserangabe: `Toxin : Thriller / Kathrin Lange, Susanne Thiele`
  → alles ab `" / "` fällt weg, `" : "` wird zu `": "`.
- `dc:creator` steht mehrfach mit Rolle: `Lange, Kathrin [Verfasser]`. Verfasser haben
  Vorrang; gibt es keinen, bleiben Herausgeber oder Übersetzer.
- `dc:format` trägt den Umfang: `459 Seiten`.
- Unbekannte ISBN → `numberOfRecords 0`.

## Warum Cover von Amazon

Freie Quellen führen für deutsche Ausgaben oft kein Bild — und die Titelsuche liefert
dann die **englische** Ausgabe. Bei „Kill for me" (9783442494033) kam so ein fremdes
Cover statt der Goldmann-Ausgabe.

Amazon führt Cover unter der **ISBN-10**, also ausgabegenau:

```
https://m.media-amazon.com/images/P/<ISBN-10>.01.LZZZZZZZ.jpg
```

Live: `9783442494033` → `3442494036` → 24.896 Byte JPEG der deutschen Ausgabe.
`images-amazon.com` ohne Subdomain antwortet nicht; `m.media-amazon.com` und
`images-na.ssl-images-amazon.com` liefern dasselbe Bild.

### ⚠️ Der Fallstrick: fremde Produktbilder

Der Endpunkt nimmt **jede Artikelnummer**, nicht nur Bücher. `1234567890` hat eine
falsche ISBN-10-Prüfziffer, ist bei Amazon aber eine gültige Artikelnummer — und
lieferte ein Foto von **Bremsscheiben**, 20.581 Byte groß, also am Größencheck vorbei.

Deshalb: Die ISBN-10 wird selbst gerechnet und die **Prüfziffer verifiziert**, bevor
überhaupt angefragt wird. 979er-ISBN haben keine ISBN-10-Entsprechung und fallen durch.
Ein echter Nichttreffer antwortet mit 43 Byte und greift damit im Größencheck.

## Weitere Fallstricke

- **Open Library liefert 1×1-Pixel statt 404.** Alles unter 1.500 Byte gilt als kein Bild
  (`CoverCache.minimumImageBytes`).
- **Titelsuche ohne Autor-Abgleich holt falsche Cover.** „Broken" von Don Winslow bekam
  einmal das Cover von „Once Upon a Broken Heart". Jeder Treffer wird gegen den Autor
  geprüft (`AuthorMatch`).
- **Suchtitel müssen bereinigt werden.** Die DNB liefert
  `[Kill for me, kill for you] ; Kill for me: Thriller: sie tötet …`; damit findet keine
  Suche etwas. `SearchTitle.simplify` macht daraus `Kill for me`.
- **Open-Library-Suchtreffer haben oft keine ISBN**, aber ein `cover_i`. Daraus wird
  `https://covers.openlibrary.org/b/id/<id>-L.jpg` — die Adresse antwortet mit **302**,
  Weiterleitungen müssen also verfolgt werden.
- **Google meldet `pageCount: 0`**, wenn der Umfang unbekannt ist — das gilt als keine
  Angabe, nicht als null Seiten.

## Titel-Bereinigung

Katalogtitel schleppen Ballast mit, der nicht auf dem Buchrücken steht.
`TitleCleanup.clean` (greift bei Lookup **und** Import) entfernt:

- Ausgabevariante in eckigen Klammern: `[Upgrade] ; Upgrade: Roman` → `Upgrade`
- weitere Fassungen hinter `" ; "`, Verfasserangabe hinter `" / "`
- Klappentext-Reste, die auf `...` enden
- **reine** Gattungszusätze (Roman, Thriller, Kriminalroman, …; max. 3 Wörter,
  alle aus der Wortliste): `Wer Lügen sät: Thriller` → `Wer Lügen sät`

Echte Untertitel bleiben (`Sapiens: Eine kurze Geschichte der Menschheit`), ebenso
Aufzählungen mit mehreren Gedankenstrichen (`Wäller Weihnacht. Gedichte - Brauchtum -
Geschichten`). Zwei Invarianten sind als Test gegen die echten Exportdaten verankert:
kein Titel wird leer, jede Kürzung ist ein Präfix des Originals. Gemessene Wirkung:
18 von 108 Titeln im Sample, 199 von 1780 im Vollbestand.

⚠️ Der Dublettenschlüssel muss mit dem **bereinigten** Titel rechnen — sonst legt ein
zweiter Import Bücher ohne ISBN doppelt an (live passiert, per Test abgesichert).

## Dubletten

Dieselbe ISBN zweimal einzugeben legt kein zweites Buch an: `LibraryStore.book(isbn:in:)`
findet den vorhandenen Eintrag, und der Lookup läuft erneut für ihn. So repariert sich
auch ein Buch, dessen erster Lookup leer blieb.

Der Import nutzt `DuplicateKey`: ISBN als Schlüssel, ersatzweise Titel + Autor in
Kleinschreibung. Bücher ohne ISBN lassen sich damit nur über Titel und Autor
unterscheiden — fehlt beides, greift der Schutz nicht.

## Cover-Nachlauf für den Bestand

Importierte Bücher kommen ohne Bild. `CoverBackfill` holt Cover für alles nach, was
keins hat — sequenziell mit 1 s Pause (Google drosselt Schwälle):

```bash
./LibraryCompass.app/Contents/MacOS/LibraryCompass --fetch-covers
```

Nur bei geschlossener App laufen lassen (gleicher SwiftData-Store). Lauf über den
echten Bestand am 2026-08-05: `geprüft=109 ergänzt=101`. Die Reste: Bücher ohne ISBN
und ohne Autor (Titelsuche wird zu Recht verworfen) sowie alte ISBN-10, zu denen auch
Amazon nichts führt.

Wichtig dabei: Die Cover-Kette ist eine eigene Methode (`coverURL(isbn:title:author:)`)
und läuft auch, wenn **keine** Quelle Metadaten liefert — Metadaten-Treffer und
Cover-Treffer sind unabhängige Ereignisse.

Was **nach** dem gefundenen Bild passiert — Dateiname je Buch (`CoverKey`), Ablage,
Wiederaufnahme, Vollständigkeitsnachweis und die zwei Fehler, die am 1.780er-Bestand
sichtbar wurden — steht in **[covers.md](covers.md)**.

## Amazon identifiers are not ISBNs

Reported 2026-08-09: „Die Killerin — Isabella Rose" could not be added. Amazon lists it as
`B0BHG35KD6`, an ASIN. `ISBN.normalized` keeps only digits and „X", so `B0BHG35KD6` became
`0356` — the entry got an ISBN that does not exist, and every lookup for it was doomed.

Two guards now stand in front of that:

- `ISBN.isPlausible` requires ten or thirteen digits **with a valid check digit**. Anything
  else is not an ISBN and is not treated as one.
- `AmazonReference` recognises an ASIN (ten characters, starts with „B") and pulls the
  identifier out of a pasted product URL (`/dp/…`, `/gp/product/…`). A product page may
  carry either an ISBN-10 or an ASIN, so the extracted value still goes through
  `isPlausible`.

E-books and self-published titles frequently have **no ISBN at all** — the Amazon image
endpoint does not know ASINs either (measured 2026-08-08: `B0GNS692YT` → 43 bytes), and no
catalogue looks them up. So the dialog asks for title and author instead and creates the
entry without an ISBN.

The author is required on that path, deliberately. Without an ISBN the only remaining cover
source is the title search, and that search needs the author as its anchor — a title alone
attaches whatever happens to match. „Flashback" returned nine different books this way.

## Filling in missing authors

The author is not decoration. It is the **anchor of every further search**: without it the
title search must not run at all, because it has nothing to check its hits against —
„Flashback" alone returns nine different books. On 2026-08-10, 30 of the 114 coverless
books had no author and were therefore permanently excluded from cover lookup.

```bash
LibraryCompass --fetch-authors
```

The rule is the strictest one available: **one title, one author.** If the records for a
title name more than one person, the field stays empty. A wrong author pulls a wrong cover
in behind it, and then there are two errors in the record instead of one gap.

### Uniqueness must be judged on the whole list

The first version of this pass asked for ten records and treated uniqueness *among those
ten* as uniqueness. It wrote 80 authors, 40 of which could not be substantiated:

- „Phantom" → „Matsuri", while the DNB holds **4921** records for that word
- „Falsche Schuld. Private London" → „Minninger" instead of Patterson, at 65 hits

All 80 were rolled back. The pass now requests 100 records and compares `numberOfRecords`
against what actually arrived; if the list is truncated, it returns nothing. Whoever sees
only an excerpt may not rule on uniqueness.

Co-authors of one book are not a contradiction — „Operation Seewespe" lists Cussler and
Morrison, and that is one book, not two opinions about who wrote it. Only the first author
of each record counts.

## Correcting an author by hand

```bash
LibraryCompass --apply-authors assignment.tsv
```

Same format as `--apply-covers`: key, tab, value; an empty value clears the field. This is
the way back when a pass gets it wrong — without it, 80 unverifiable authors would have
stayed in the library for good.

The key may be the title hash even for books that *have* an ISBN. Two entries of the same
book can carry the same ISBN in both notations — `3442481163` and `9783442481163` — and a
key over the ISBN then matches both, leaving neither correctable.
