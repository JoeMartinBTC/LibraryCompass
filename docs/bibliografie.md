# Autorbibliografie und Lückenkorb

Der Knopf **Autorbibliografie** in der Detailansicht holt die Werkliste des Verfassers
bei der DNB, hält sie gegen den Bestand und legt, was fehlt, in einen **eigenen** Korb —
mit Coverbild, eigener Zeile in der Seitenleiste und eigener Zählung.

> Eine Lücke ist kein Buch dieser Bibliothek. Sie steht in `MissingBook`, nicht in `Book`,
> und `FetchDescriptor<Book>` sieht sie deshalb gar nicht erst. Kein Zähler, kein CSV-Export
> und kein Web-Export kann sie versehentlich mitnehmen.

## Der Weg

1. **Werkliste** — `DNB.personURL(person:)` fragt `PER=<ganzer Name>`, seitenweise zu 100
   Datensätzen, bis die Trefferliste zu Ende ist (`MetadataLookup.bibliography(author:)`).
2. **Wächter** je Datensatz (`AuthorBibliography.works`) — Verfasserrolle, kein Erzähler,
   Druckausgabe, keine reine Online-Ressource, deutsche Sprachangabe, mindestens eine ISBN.
3. **Ausgaben zu Werken** zusammenfassen — über alle Titel eines Datensatzes; die älteste
   Ausgabe gibt Titel, Jahr und ISBN.
4. **Abgleich** (`AuthorBibliography.gaps`) — gegen die Bücher **desselben Verfassers**,
   über die kanonische ISBN und über `TitleMatch.sameWork` gegen jeden Titel des Werks.
5. **Cover** — dieselbe Kette wie beim Bestand (Amazon über ISBN-10 zuerst), sequenziell
   mit Pause, abgelegt im selben Cover-Cache (`BibliographyRun.run`).

Ein zweiter Lauf für denselben Verfasser **ersetzt** dessen Lücken. Sonst bliebe ein Werk
im Korb stehen, das inzwischen im Regal steht.

## Was diese Wächter gekostet haben

Alles an der echten Antwort zu `PER=Frank Schätzing` gemessen (2026-08-10, 323 Datensätze):

| Datensatz | Warum er nicht ins Werkverzeichnis gehört |
|---|---|
| „Die Juden von Cölln … mit einem Vorwort von Frank Schätzing" | Verfasser ist Wilhelm Jensen; Schätzing steht als `[Mitwirkender]` |
| „Tod und Teufel / Frank Schätzing" (der Hörverlag) | Eine **Lesung** — im Titel steht kein Wort davon, nur `[Erzähler]` im Datensatz |
| „The swarm : a novel", „L' essaim", „Ölüm ve şeytan", „Qiao wu sheng xi" | Übersetzungen von Büchern, die auf Deutsch schon in der Liste stehen |
| „Part two" | Teilband ohne ISBN — kein Cover, nichts zu bestellen |
| „Mordshunger : [mit einem Lieblingsrezept …]" neben „Mordshunger" | Ein Werk, zwei Katalogtitel |

Zwei Fallen, die erst der Blick auf die echten Daten zeigte:

- **Die eckige Klammer trägt nicht immer einen Titel.** Neuere Ausgaben laufen unter
  `[Schätzing] ; Helden : Roman` — der Verfassername als Reihe. Wer das als Titel nimmt,
  hält „Helden", „Die Tyrannei des Schmetterlings" und „Was, wenn wir einfach die Welt
  retten?" für ein Werk: aus 13 wurden 10.
- **Die Sprachangabe ist der Unterschied.** Die fremdsprachigen Ausgaben führen gar keine
  (türkisch, chinesisch, französisch) oder `eng`; die deutschen Druckausgaben führen `ger`.
  Deshalb ist eine fehlende Sprachangabe ein Ausschluss, kein Freifahrtschein.

## Vollständigkeit

`BibliographyResult.isComplete` sagt, ob der Lauf den Katalog zu Ende gelesen hat. Eine
gekürzte Liste darf sich nicht als ganze ausgeben — dieselbe Regel wie beim Cover-Nachlauf:
**Eindeutigkeit in einem Ausschnitt ist keine Eindeutigkeit.**

## Probe

`AuthorBibliographyLiveTests` fragt die DNB wirklich und überspringt sich, wenn der Dienst
ausfällt. Die Werkliste wird dabei ausgedruckt — Zählerstände belegen nichts, angesehen
werden muss die Liste.
