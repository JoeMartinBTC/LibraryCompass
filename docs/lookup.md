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

## Dubletten

Dieselbe ISBN zweimal einzugeben legt kein zweites Buch an: `LibraryStore.book(isbn:in:)`
findet den vorhandenen Eintrag, und der Lookup läuft erneut für ihn. So repariert sich
auch ein Buch, dessen erster Lookup leer blieb.

Der Import nutzt `DuplicateKey`: ISBN als Schlüssel, ersatzweise Titel + Autor in
Kleinschreibung. Bücher ohne ISBN lassen sich damit nur über Titel und Autor
unterscheiden — fehlt beides, greift der Schutz nicht.

## Bekannte Lücke

Für Bücher aus dem Import gibt es **keinen Cover-Nachlauf**. Cover werden nur beim
Hinzufügen per ISBN geladen; die importierten Bände bleiben ohne Bild, bis ihre ISBN
erneut eingegeben wird.
