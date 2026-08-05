# Eigener Google-Books-Schlüssel

Ohne Schlüssel fragt LibraryCompass Google Books anonym. Google drosselt das hart
pro Tag — am 2026-08-05 kam bereits bei der ersten Abfrage
`429 Quota exceeded for quota metric 'Queries' and limit 'Queries per day'`.
Titel und Autor holt seitdem die Deutsche Nationalbibliothek, **Cover liefert sie
aber nicht**. Für Cover deutscher Ausgaben ist ein eigener Schlüssel der einzige
verlässliche Weg.

Der Schlüssel gehört **nie ins Repo**. Er liegt neben dem Datenbestand:
`~/Library/Application Support/LibraryCompass/google-books-key.txt`

## Schlüssel besorgen

Laut Googles eigener Anleitung
([developers.google.com/books/docs/v1/using](https://developers.google.com/books/docs/v1/using),
abgerufen 2026-08-05):

1. Die Seite [Anmeldedaten in der API-Konsole](https://console.cloud.google.com/apis/credentials) öffnen.
2. **Anmeldedaten erstellen → API-Schlüssel** wählen.
3. Vor dem produktiven Einsatz optional **Schlüssel einschränken** — für diesen
   Zweck genügt eine Beschränkung auf die Books API.

Zusätzlich muss die Books API im gewählten Projekt aktiviert sein. Diese Schritte
laufen in deinem Google-Konto — sie kann dir kein Agent abnehmen.

## Schlüssel hinterlegen

```bash
./set-google-key.sh AIza…deinSchlüssel
```

Das Skript legt die Datei mit Rechten `600` an und prüft den Schlüssel sofort mit
einer echten Abfrage. Erwartete Ausgabe bei Erfolg: `HTTP 200` plus der gefundene
Titel. Bei `HTTP 400` ist der Schlüssel ungültig, bei `HTTP 403` fehlt die
Freischaltung der Books API im Projekt.

Danach die App neu starten — der Schlüssel wird beim Start gelesen.

## Alternativen zur Datei

Für Skripte und Testläufe sticht die Umgebungsvariable die Datei:

```bash
GOOGLE_BOOKS_API_KEY=AIza…deinSchlüssel swift test --filter LookupTests
```

## Wie der Schlüssel benutzt wird

Google erwartet ihn als Abfrageparameter `key=…` an der Volumes-Adresse; genau so
hängt ihn `GoogleBooks.volumesURL(isbn:key:)` an. Open Library und die DNB
bekommen ihn nie zu sehen — das prüft `GoogleBooksKeyTests`.

## Schlüssel wieder entfernen

```bash
rm ~/Library/Application\ Support/LibraryCompass/google-books-key.txt
```

Danach fragt die App wieder anonym an.
