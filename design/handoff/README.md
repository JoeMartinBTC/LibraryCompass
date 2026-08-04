# Handoff: LibraryCompass — UI-Redesign (SwiftUI)

**Auftraggeber:** Joe Martin · **Stand:** 2026-08-04 · **Sprache der App:** Deutsch
**Design-Referenz:** CleanMyMac (MacPaw), App-UI — violetter Verlaufsgrund, Glasflächen, weiche Glows, große leichte Typografie, genau eine Hauptaktion pro Screen.

---

## 1 · Überblick

LibraryCompass ist eine private Mac-App für eine physische Buchbibliothek (~1.800 Bücher, ein einziger Nutzer, täglich kurze Sessions). Sie zeigt die Bibliothek als Cover-Grid oder Liste, filtert über eine Seitenleiste, sucht und sortiert, und erlaubt im Detail-Panel eine eigene Sternebewertung, einen Kommentar und ein Gelesen-Datum. Bücher kommen per ISBN-Dialog oder Import aus Delicious Library hinein.

Dieses Bündel beschreibt **ausschließlich das UI**. Der Funktionsumfang ist gegenüber der bestehenden App unverändert: kein Feature dazu, keins weg.

---

## 2 · Über die Design-Dateien

Die beiliegenden Dateien sind **Design-Referenzen in HTML** — ein Prototyp, der Aussehen und Verhalten zeigt. Sie sind **kein Produktionscode zum Übernehmen**.

Aufgabe: **die Designs in SwiftUI nachbauen** (macOS 14+, AppKit-Integration wo nötig), mit den Mustern und Bibliotheken des bestehenden LibraryCompass-Projekts. Die HTML-Umsetzung ist eine Klick-Simulation mit generierten Beispieldaten; die echten Daten kommen aus dem bestehenden Model der App.

**Was zwingend aus dem HTML zu übernehmen ist:** Farben, Verläufe, Radien, Schatten, Typo-Skala, Spacing, Maße, Interaktionsverhalten, Texte. Alles davon steht in `TOKENS.md` und in Abschnitt 5–9 dieses Dokuments.

**Was NICHT zu übernehmen ist:** die HTML-Struktur, die Cover-Platzhalterverläufe (nur solange kein echtes Cover vorliegt), die generierten Buchtitel/Autoren.

---

## 3 · Fidelity

**High-Fidelity.** Farben, Typografie, Spacing und Interaktionen sind final. Der Nachbau soll pixelgenau erfolgen — mit SwiftUI-Bordmitteln (`LinearGradient`, `RadialGradient`, `.ultraThinMaterial` bzw. explizite Glas-Farben, `.shadow`, `Color`), nicht mit WebViews.

---

## 4 · Fenster & Grundgerüst

Ein Fenster, drei Spalten, kein weiterer Navigationszustand:

```
┌──────────────┬───────────────────────────────────────┬──────────────┐
│  Seitenleiste │  Toolbar (54)                         │ Detail-Panel │
│  252 (180–400)│  Titelzeile + Statistik-Umschalter    │ 352, optional│
│  zuklappbar   │  Statistik-Karten (klappbar, ~170)    │              │
│               │  Scrollbereich: Grid oder Liste       │              │
│               │  Floating-Hauptaktion (52, unten mitte)│             │
└──────────────┴───────────────────────────────────────┴──────────────┘
```

- Fenster-Radius 14, Schatten `shadowWindow`.
- Der **Verlaufsgrund** liegt auf dem Fenster, nicht auf den Spalten. Seitenleiste und Detail-Panel sind halbtransparente Glasflächen **darüber** (`sidebar`-Token + Blur 24).
- macOS-Fensterrahmen bleibt; Traffic-Lights sitzen in der Seitenleiste. Ist die Seitenleiste zugeklappt, wandern sie in die Toolbar (links, vor dem Klapp-Button).
- Designbreite des Prototyps: 1440 × 920. Das Layout ist fluide: Seitenleiste und Detail-Panel sind fix bzw. ziehbar, die Mittelspalte nimmt den Rest.
- **Kein horizontales Scrollen** in irgendeinem Zustand.

### Hintergrund (die wichtigste Ebene)

Kein Flächenfarbton, sondern ein Verlaufsstapel. In SwiftUI als `ZStack`:

```swift
ZStack {
    LinearGradient(colors: [.init(hex: 0x28104E), .init(hex: 0x1B0C36), .init(hex: 0x150A2C)],
                   startPoint: .init(x: 0.12, y: 0), endPoint: .init(x: 0.88, y: 1))   // ≈163°
    RadialGradient(colors: [.init(hex: 0x5A2497), .clear], center: .init(x: 0.10, y: -0.12),
                   startRadius: 0, endRadius: 0.95 * height)
    RadialGradient(colors: [.init(hex: 0x2E3FA8), .clear], center: .init(x: 0.97, y: 0.06), …)
    RadialGradient(colors: [.init(hex: 0x7A2A9E), .clear], center: .init(x: 0.60, y: 1.08), …)
}
```

Hell: Basis `#FAF7FF → #F3EEFD`, Glows `#E5D6FF`, `#D9E3FF`, `#F0DAFB`.
Vollständige Werte: `TOKENS.md`, Abschnitt 1.

---

## 5 · Screens / Ansichten

### 5.1 Seitenleiste

**Zweck:** Filter und Genre-Auswahl, Einstieg in den Import.

**Layout:** Breite 252 (Standard), **ziehbar 180–400**, **zuklappbar**. Innen `padding 6 12 14`. Titelleistenbereich 54 hoch mit Traffic-Lights (`padding 0 20`, Gap 8, je 12 px Kreis: `#FF5F57`, `#FEBC2E`, `#28C840`). Unten abgetrennter Footer (`border-top brd`, `padding 12`).

**Filterzeilen (4 Stück, oben, ohne Abschnittslabel):**
- Zeile: `padding 8 11`, `cornerRadius 12`, Abstand 3, Gap 11.
- Links ein **Icon-Tile** 26 × 26, `cornerRadius 9`, Verlauf 150°, Schatten `0 3 10 <g2>`, darin ein weißes 15-px-Strichsymbol (Strichstärke 1.5, runde Enden):

  | Zeile | Symbol | Tile-Verlauf |
  |---|---|---|
  | Alle Bücher | Buchstapel | `#B45CFF` → 55 % `#7B3BE8` |
  | Gelesen | Häkchen | `#56E39F` → 55 % `#177A5A` |
  | Ungelesen | Kreis mit Strich | `#FFB347` → 55 % `#B8531A` |
  | Bewertet | Stern | `#FFC24F` → 55 % `#8A6516` |

- Label `bodyM` (13.5), Zähler rechts `captionS` (11.5) in `text3`, `tabular-nums`, mit `de-DE`-Tausenderpunkt.
- **Aktiv:** Hintergrund `glass2`, 1-px-Ring `brd2`, Label `text` / Weight 560. **Inaktiv:** transparent, Label `text2` / Weight 450. **Hover:** `glass2`.

**Genres (10 Stück, darunter):**
- Abschnittslabel „GENRES" — `label`-Token (10.5 / 700 / +0.09em / uppercase / `text3`), `padding 20 11 8`.
- Zeile: `padding 6 11`, `cornerRadius 10`, Gap 12. Links ein 8-px-Quadrat, `cornerRadius 3`, Genre-Farbe, Glow `0 0 10 <eigene Farbe>`. Label `body` (13). Zähler wie oben.
- Genres in dieser Reihenfolge mit diesen Farben:
  `Roman #B45CFF` · `Sachbuch #4FD8E8` · `Krimi #FF6BC1` · `Lyrik #FFC24F` · `Geschichte #6BA8FF` · `Philosophie #56E39F` · `Kunst #FF8A6B` · `Science-Fiction #A0E85C` · `Biografie #C36BFF` · `Reise #3AC8E0`
- Aktiv-/Hover-Zustände wie bei den Filtern (Hover hier `glass`).

**Footer:** eine Zeile „Delicious Library importieren", `padding 8 11`, `cornerRadius 11`, Gap 10, links ein 26-px-Tile in `glass2` mit `brd`-Rahmen und Download-Symbol (Pfeil nach unten über Grundlinie), Text `caption` in `text2`, Ellipse bei zu geringer Breite. Öffnet den Import-Dialog.

**Ziehen:** 7 px breite Ziehfläche an der rechten Kante (3 px über die Kante hinaus), Cursor `col-resize`. Die Breite folgt dem Cursor **1:1 ohne Animation**, geklemmt auf 180–400.

**Zuklappen:** Über den Toolbar-Button. Zugeklappt wird die Spalte komplett entfernt (Breite 0), nicht auf Icon-Breite reduziert.

---

### 5.2 Toolbar (54 hoch, `padding 0 26`, Gap 10)

Von links nach rechts:

1. **Traffic-Lights** — nur wenn die Seitenleiste zugeklappt ist, Gap 8, `margin-right 4`.
2. **Seitenleisten-Umschalter** — 32 × 32, `cornerRadius 11`, `brd`-Rahmen. Hintergrund `glass` (offen) bzw. `glass3` (zugeklappt). Symbol: Rechteck mit senkrechter Trennlinie links, `text2`.
3. **Suchfeld** — Breite 288, Höhe 32, `cornerRadius 11`, `glass` + `brd` + Blur 18. Links Lupe 14 px in `text3`, Platzhalter „Titel oder Autor suchen" in `text3`. Bei Eingabe erscheint rechts ein 17-px-Löschkreis (`glass3`, `text2`, „✕"). Fokusring: 1.5 px `accent`, innen.
4. **Spacer**
5. **Zoom-Regler** — Höhe 32, `padding 0 12`, `cornerRadius 11`, `glass` + `brd`, Gap 9:
   - „−"-Taste 16 × 16, `cornerRadius 5`, Hover `glass3`
   - Spur 86 × 4, `cornerRadius 2`, `glass3`; Füllung `LinearGradient(cyan → accent)`; Knopf 12 px weiß, Schatten `0 1 4 rgba(0,0,0,.35)`
   - „+"-Taste wie „−"
   - Prozentanzeige, `captionS` in `text3`, Breite 40, rechtsbündig, `tabular-nums`, nie umbrechen
6. **Sortierung** — `Picker`/Popup, Höhe 32, `cornerRadius 11`, `glass` + `brd` + Blur 18, `caption`. Optionen exakt: „Titel A–Z", „Autor A–Z", „Jahr, neueste zuerst", „Bewertung, beste zuerst", „Zuletzt gelesen".
7. **Ansichts-Umschalter** — Segmented, `padding 3`, Gap 3, `cornerRadius 12`, `glass` + `brd`. Zwei Segmente 36 × 26, `cornerRadius 9`. Aktives Segment: Hintergrund `glass3`, Symbol in `text`; inaktiv: transparent, Symbol `text3`. Symbole: 2 × 2-Punktraster (Grid) / drei 13-px-Linien (Liste).
8. **Erscheinungsbild** — 32 × 32, `cornerRadius 11`, `glass` + `brd`. Glyphe zeigt den Zustand: `◐` automatisch, `○` hell, `●` dunkel. Klick schaltet zyklisch auto → hell → dunkel.

---

### 5.3 Titelzeile (`padding 4 26 0`, Baseline-ausgerichtet)

- **Links:** Screen-Titel, `screenTitle` (36 / Weight 300 / −0.03em). Inhalt: der Name des aktiven Filters („Alle Bücher", „Gelesen", „Ungelesen", „Bewertet") oder — wenn ein Genre gewählt ist — der Genre-Name.
- **Rechts** (Gap 12, `padding-bottom 7`):
  - Anzahl: `caption` in `text3`, `tabular-nums`, Format **„{angezeigt} von {gesamt} Titeln · {Sortierung}"**, z. B. „183 von 1.800 Titeln · Titel A–Z". Bleibt auch bei eingeklappter Statistik sichtbar.
  - **Statistik-Umschalter:** Höhe 26, `padding 0 11`, `cornerRadius 9`, `brd`-Rahmen, Hintergrund `glass` (offen) / transparent (zu). Text „Statistik" `captionS` in `text2`, dahinter ein 10-px-Chevron; offen um 180° gedreht (zeigt nach oben). Hover: `glass2`, Text `text`.

---

### 5.4 Statistik-Karten (klappbar)

Drei Karten in einem Grid `minmax(0, 1.32fr) minmax(0, 1fr) minmax(0, 1fr)`, Gap 14, `padding 12 26 16`. Jede Karte: `cornerRadius 20`, `glass` + `brd` + Blur 20, `shadowCard`, `padding 16 20`, `overflow: hidden`.

> **Wichtig:** Die Spalten müssen unter ihre Content-Mindestbreite dürfen (`minmax(0, …)` bzw. in SwiftUI `.frame(minWidth: 0)` + `.layoutPriority`). Bei gleichzeitig maximal breiter Seitenleiste (400) und offenem Detail-Panel bleibt für die Mittelspalte nur ~686 px; Karteninhalte müssen dann **kürzen**, nicht überlaufen.

**Karte 1 — Bibliothek (Gap 20, vertikal zentriert)**
- Deko: 230-px-Kreis, `RadialGradient(rgba(79,216,232,.30) → clear)`, rechts −70 / oben −80, wird beschnitten.
- **Fortschrittsring** 84 × 84: `conic-gradient` ab −90°, `cyan` → `accent` bis zum Leseanteil, Rest `glass3`; Ringbreite 7 (Innenkreis wieder mit `bgLayers` gefüllt); Glow `ringGlow`. Innen zweizeilig: Prozent (`ringValue`, 20 / 400, `tabular-nums`) und „GELESEN" (`label`, 9 px, `text3`).
- Rechts (flexibel, `minWidth 0`): „Meine Bibliothek" (`caption`, `text2`, Ellipse) · Gesamtzahl (`heroNumber`, 32 / 300, `tabular-nums`) · Delta-Zeile „▲ {n} gelesen" (`caption` in `mint`, Dreieck 9 px, Text kürzt mit Ellipse) · Balken `width 100%, maxWidth 230`, Höhe 7, `cornerRadius 4`: gelesener Anteil `LinearGradient(mint → cyan)`, Rest `glass3`, Lücke 2.

**Karte 2 — Eigene Bewertungen**
- „Eigene Bewertungen" (`caption`, `text2`) · Anzahl bewerteter Bücher (`statNumber`, 28 / 300) · Sternzeile: gerundeter Durchschnitt als ★-Reihe in `gold` (Tracking 1) plus „Ø 3,6" in `text3` (`de-DE`-Dezimalkomma).
- Verteilung 5 → 1 Sterne, Gap 4: Label als ★-Reihe (10.5, `text3`, Breite 34) · Spur 5 px `cornerRadius 3` `glass3` mit Füllung `LinearGradient(gold → pink)`, Breite relativ zum größten Balken · Anzahl rechts (10.5, `text3`, Breite 30, `tabular-nums`).

**Karte 3 — Zuletzt gelesen**
- Deko: 190-px-Kreis `RadialGradient(rgba(255,107,193,.26) → clear)`, rechts −60 / unten −80.
- „Zuletzt gelesen" (`caption`, `text2`), darunter die **4 zuletzt gelesenen Bücher** (Gap 7): Cover-Thumbnail 20 × 29 (`cornerRadius 3`, `shadowCover`) · Titel (12, Ellipse) · Datum rechts (11, `text3`, `tabular-nums`, `dd.MM.yyyy`, nie umbrechen). Klick wählt das Buch aus (öffnet das Detail-Panel).
- Zeilen-Hover: `glass2`, `cornerRadius 8`.

**Eingeklappt:** Die ganze Reihe verschwindet, an ihrer Stelle bleiben 14 px Luft. Der Scrollbereich rückt sofort nach oben — ohne Animation.

---

### 5.5 Cover-Grid

- Container: Scrollbereich `padding 0 26 104` (unten Platz für die Floating-Aktion), `overflow-x: hidden`.
- Grid: `repeat(auto-fill, minmax(coverW, 1fr))`, `coverW = 146 × zoom`, Gap 26 vertikal / 20 horizontal, oben ausgerichtet.
- **Karte:** Auswahlfläche mit `padding 8` / `margin -8` und `cornerRadius 18`. Ausgewählt: Hintergrund `glass2` + Ring `0 0 0 1 brd2` und `0 10 30 rgba(0,0,0,.22)`. Hover: `glass`.
- **Cover:** Verhältnis 2 : 3, `cornerRadius 11`, `shadowCover`, `padding 14 13`. Darin
  - Buchrücken: 6 px links, `LinearGradient(90°, rgba(0,0,0,.30) → rgba(255,255,255,.10))`
  - Zwei Overlays: Glanz `linear 200°, rgba(255,255,255,.20) → transparent 40 %` und Lesbarkeit `linear 180°, rgba(0,0,0,.30) → transparent 38 % → transparent 66 % → rgba(0,0,0,.30)`
  - Oben der Titel (`coverTitle`, 13 / 600, weiß 97 %, Schatten `0 1 3 rgba(0,0,0,.25)`, `padding-left 7`), unten der Autor (`coverAuthor`, 8.5 / 600 / +0.11em / uppercase, weiß 74 %)
  - Liegt ein echtes Cover-Bild vor, ersetzt es **nur** den Verlauf; Buchrücken, Overlays und Beschriftung entfallen dann.
- **Unter dem Cover:** Titel (`body`, max. 2 Zeilen, danach abgeschnitten), Autor (`captionS`, `text3`, eine Zeile mit Ellipse), Sternzeile (10.5, `gold`, Tracking 1, feste Höhe 14 — damit die Zeilen nicht springen, wenn ein Buch unbewertet ist).

### 5.6 Listenansicht

- Kopfzeile: `padding 0 16 8`, Gap 16, `label`-Token. Spalten: Thumbnail-Breite (leer) · „Titel" (flexibel) · „Genre" 130 · „Jahr" 48 · „Bewertung" 74 · „Gelesen" 96 rechtsbündig.
- Zeilen: Gap 3, Höhe `58 × zoom`, `padding 0 16`, `cornerRadius 13`. Hover `glass`; ausgewählt wie im Grid (`glass2` + Ring).
- **Cover-Thumbnail** `34 × 50 × zoom`, `cornerRadius 4`, `shadowCover`, mit 3-px-Buchrücken und Glanz-Overlay. Ist Pflicht — die Liste zeigt immer eine Cover-Vorschau.
- Titel (`body`) über Autor (`captionS`, `text3`), beide mit Ellipse. Genre mit 6-px-Farbmarker davor (`caption`, `text2`). Jahr und Datum `tabular-nums`, Datum `dd.MM.yyyy` bzw. „–" wenn ungelesen. Bewertung als ★-Reihe in `gold`.

### 5.7 Leerzustand (keine Treffer)

Zentriert, `padding 90 0`, Gap 12: 64-px-Tile `cornerRadius 20`, `LinearGradient(150°, accent → accent2)`, `glow`, darin eine 28-px-Lupe in Weiß · „Keine Treffer" (17 / 400) · „Für „{Suchbegriff}" ist in dieser Auswahl kein Buch vorhanden." (`body`, `text2`, max. 300 breit, zentriert).

### 5.8 Floating-Hauptaktion

- Pille, unten mittig, `bottom 26`, Höhe 52, `padding 0 34`, `cornerRadius 26`, `LinearGradient(150°, accent → accent2)`, `glow`, Gap 10: 16-px-Plus-Symbol + „Buch hinzufügen" (`action`, 14.5 / 500, `accentInk`). Hover: `brightness 1.1`.
- Darunter ein 112 px hoher **Scrim** über die ganze Breite (`scrim`-Token, `pointer-events: none`), damit der Button auf jedem Cover lesbar bleibt.
- Das ist die **einzige** Hauptaktion des Screens. Alles andere in der App bleibt visuell zurückhaltend.

### 5.9 Detail-Panel (352 breit, optional)

- Glasspalte rechts, `sidebar`-Token + Blur 24, `border-left brd`. Kopf 54 hoch: Label „DETAILS" (`label`) links, Schließen-Button 26 × 26 (`cornerRadius 9`, Hover `glass2`) rechts. Inhalt scrollt, `padding 2 24 28`.
- **Großes Cover** 158 breit, 2 : 3, `cornerRadius 14`, `shadowSheet`, gleiche Overlays wie im Grid, Titel 15 / 600, Autor 9 px uppercase.
- Titel (`detailTitle`, 21 / 400), Autor (`body`, `text2`).
- Drei Chips (Gap 6): Genre · Jahr · „{n} Seiten" — `padding 5 11`, `cornerRadius 9`, `glass` + `brd`, `captionS` in `text2`.
- **Bearbeitungskarte** (`cornerRadius 18`, `glass` + `brd`, `shadowCard`, `padding 16 18`):
  - „MEINE BEWERTUNG" (`label`) · fünf Sterne 25 px, Gap 6. Gesetzt: `gold` + `starGlow`; ungesetzt: `glass3`. Klick auf Stern *n* setzt die Bewertung auf *n*. Rechts „zurücksetzen" (`captionS`, `text3`) setzt sie auf 0.
  - „GELESEN AM" (`label`) · Datumsfeld (Höhe 33, `cornerRadius 10`, `glass2` + `brd`, `caption`) + Taste „Heute" (Höhe 33, `padding 0 13`, `cornerRadius 10`, `brd`-Rahmen) setzt das heutige Datum.
  - „KOMMENTAR" (`label`) · Textfeld, Höhe 100, nicht größenveränderbar, `padding 11 13`, `cornerRadius 13`, `glass2` + `brd`, `caption`, Zeilenhöhe 1.5, Platzhalter „Notiz zu diesem Buch …".
- Fußzeile: „ISBN {isbn}" (`captionS`, `text3`).
- Alle drei Eingaben schreiben sofort auf das Buch (kein Speichern-Button).

### 5.10 ISBN-Dialog

Overlay `rgba(12,5,28,.52)` + Blur 8, Sheet 466 breit, oben zentriert mit 130 px Abstand, `padding 28`, `cornerRadius 24`, `glass2` + `brd2` + Blur 40, `shadowSheet`.
- Kopf (Gap 13): 38-px-Tile `cornerRadius 13`, `LinearGradient(150°, accent → accent2)`, Schatten `0 6 18 rgba(180,92,255,.4)`, weißes Plus · Titel „Buch per ISBN hinzufügen" (`sheetTitle`) über „Titel, Autor und Cover werden übernommen." (`caption`, `text2`).
- Feld: Höhe 40, `cornerRadius 13`, `glass` + `brd2`, 14 px, `tabular-nums`, Platzhalter „978-3-…".
- Aktionen rechtsbündig, Gap 9: „Abbrechen" (Höhe 36, `cornerRadius 12`, `brd`-Rahmen, `text2`) · „Hinzufügen" (Höhe 36, Verlauf `accent → accent2`, Schatten `0 8 22 rgba(180,92,255,.34)`, Weight 500).
- „Hinzufügen" bei leerem Feld: keine Wirkung. Sonst: Dialog schließen, neues Buch anlegen und **auswählen** (Detail-Panel öffnet sich mit dem neuen Eintrag).

### 5.11 Import-Dialog

Wie 5.10, Sheet 506 breit, Abstand oben 120.
- Titel „Aus Delicious Library importieren" (18 / 500). Untertitel wechselt mit dem Zustand:
  - vor/laufend: „Bibliotheksdatei wählen. Bestehende Bücher werden anhand der ISBN abgeglichen."
  - fertig: „Import abgeschlossen. Bewertungen und Notizen wurden übernommen."
- Dateizeile: `padding 13 15`, `cornerRadius 16`, `glass` + `brd`, Gap 12 — 32 × 42-Vorschau (`LinearGradient(150°, #4FD8E8 → #2E3FA8)`, `shadowCover`) · Dateiname (`caption`) über „{n} Einträge · {Größe}" (`captionS`, `text3`) · Taste „Andere Datei …" (Höhe 29, `cornerRadius 10`, `brd2`-Rahmen).
- Fortschritt: Spur 7 px `cornerRadius 4` `glass3`, Füllung `LinearGradient(cyan → accent)` mit Glow `0 0 14 rgba(180,92,255,.5)`, Breite animiert 140 ms linear. Darunter Status (`captionS`, `text3`, `tabular-nums`): „Bereit" → „{n} von {gesamt} Büchern" → „{gesamt} Bücher importiert · {n} mit Bewertung".
- Aktionen: links „Abbrechen" (fertig: „Schließen"), rechts Primärtaste „Import starten" → „Importiert …" (Deckkraft 0.55, nicht klickbar) → „Fertig" (schließt).

---

## 6 · Interaktionen & Verhalten

| Auslöser | Wirkung |
|---|---|
| Filterzeile klicken | Filter setzen, Genre-Auswahl aufheben, Nachlade-Limit zurücksetzen, Scrollposition auf 0 |
| Genre klicken | Genre setzen; ein bereits aktives Genre erneut klicken hebt es auf. Filter bleibt bestehen |
| Suche tippen | sofortige Filterung (Titel + Autor, case-insensitive, Teilstring), Limit + Scroll zurücksetzen |
| Suche löschen | Löschkreis leert das Feld |
| Sortierung wählen | neu sortieren, Limit + Scroll zurücksetzen |
| Grid / Liste | Ansicht wechseln — Auswahl, Scroll und Filter bleiben; **keine** Layout-Animation |
| Karte / Zeile klicken | Buch auswählen, Detail-Panel öffnet |
| Panel schließen | Auswahl aufheben |
| Stern *n* klicken | Bewertung = *n*; „zurücksetzen" → 0 |
| Datum / „Heute" / Kommentar | schreibt sofort auf das Buch |
| Seitenleisten-Button | Seitenleiste zu-/aufklappen |
| Ziehfläche ziehen | Breite folgt dem Cursor, 180–400, ohne Transition |
| „Statistik" | Kartenreihe ein-/ausklappen, Chevron dreht 180° |
| Zoom −/+ | ±0.10, geklemmt 0.70–1.70. **Im State-Updater rechnen**, damit schnelle Doppelklicks zwei Schritte ergeben |
| Zoom-Spur klicken/ziehen | Position → Zoom, live während des Ziehens |
| Erscheinungsbild | auto → hell → dunkel → auto |
| Scrollen | ab 700 px vor dem Ende weitere 60 Titel nachladen |

**Bewegung — hart begrenzt.** 120 ms ease auf Hintergrund, Farbe, Ring und Glow. 140 ms linear auf den Import-Balken. Dialog: 120 ms ease-out, `y −10 → 0`, `scale 0.985 → 1`.
**Keine Transition auf Layout-Eigenschaften** — Größe, Position, Grid-Spalten, Sidebar-Breite, Zoom, Statistik-Klappen und Grid ↔ Liste schalten sofort. Bei 1.800 Büchern darf keine Animation zwischen Eingabe und Ergebnis stehen.

**Performance-Anforderung:** Suche und Sortierung müssen bei 1.800 Titeln unmittelbar reagieren. In SwiftUI: `LazyVGrid` / `List` mit stabilen `id`s, gefilterte Liste memoisieren (nicht in jedem `body`-Durchlauf neu sortieren), Cover-Bilder asynchron und gecacht laden.

---

## 7 · Zustand

| Zustand | Typ | Standard | Anmerkung |
|---|---|---|---|
| `filter` | enum `alle / gelesen / ungelesen / bewertet` | `alle` | |
| `genre` | Index? | `nil` | schließt Filter nicht aus, kombiniert sich mit ihm |
| `query` | String | `""` | |
| `sort` | enum (5 Werte) | `titel` | |
| `view` | enum `grid / list` | `grid` | |
| `selection` | Buch-ID? | `nil` | steuert das Detail-Panel |
| `limit` | Int | 60 | Nachladeschritt 60 |
| `dialog` | enum `nil / isbn / import` | `nil` | |
| `isbnInput` | String | `""` | |
| `importProgress` | Int 0…14 | 0 | 0 = bereit, 14 = fertig |
| `sidebarOpen` | Bool | `true` | |
| `sidebarWidth` | CGFloat | 252 | geklemmt 180–400 |
| `statsOpen` | Bool | `true` | |
| `zoom` | Double | 1.0 | geklemmt 0.70–1.70, Schritt 0.10 |
| `appearance` | enum `auto / hell / dunkel` | `auto` | |

**Reihenfolge der Auswertung:** Filter → Genre → Suche → Sortierung → Limit.
Sortierungen: Titel A–Z · Autor A–Z (Zweitschlüssel Titel) · Jahr absteigend · Bewertung absteigend · Gelesen-Datum absteigend — jeweils mit Titel als Zweitschlüssel, Vergleich mit deutscher Collation (`localeCompare('de')` → `String.compare(options: .caseInsensitive, locale: de_DE)`).

Sinnvoll zu persistieren (`@AppStorage`): `view`, `sort`, `sidebarOpen`, `sidebarWidth`, `statsOpen`, `zoom`, `appearance`.

---

## 8 · Design-Tokens

Vollständig in **`TOKENS.md`** — Farben hell/dunkel, Verlaufsstapel, Typo-Skala, Radien, Blur/Schatten, Spacing, Maße, Bewegung. Diese Datei ist die Quelle der Wahrheit; Token-Namen bitte 1:1 in die Swift-Umsetzung übernehmen (z. B. `Color.lc.glass`, `Radius.card`, `Shadow.cover`).

Kurzfassung der wichtigsten Werte:

- **Akzent:** `#B45CFF` dunkel / `#8B3FE0` hell, Verlauf 150° auf `#7B3BE8` / `#6A29C4`
- **Statusfarben:** cyan `#4FD8E8` · mint `#56E39F` · gold `#FFC24F` · pink `#FF6BC1` (hell jeweils dunkler, siehe Tabelle)
- **Glas:** `.055 / .10 / .16` Weiß auf dunkel, `.66 / .86` Weiß auf hell; Kanten `rgba(255,255,255,.11)` / `rgba(74,38,124,.12)`
- **Typo:** große Zahlen und Titel bewusst **Weight 300/400** — das ist der zentrale Ton der Referenz
- **Radien:** 20 Karte · 24 Sheet · 26 Pille · 14 Fenster · 13 Zeile · 18 Grid-Auswahl
- **Spacing:** 4-pt-Raster, Seitenrand 26, Kartenlücke 14, Grid-Gap 26/20

---

## 9 · Assets

- **Keine externen Abhängigkeiten** — keine Web-Fonts, keine Icon-Bibliothek, keine Frameworks. Typo ist SF Pro (System), alle Symbole sind einfache Strichpfade (Strichstärke 1.4–1.7, runde Enden, 16-px-Raster) und lassen sich in SwiftUI 1:1 durch **SF Symbols** ersetzen:

  | Stelle | SF Symbol |
  |---|---|
  | Alle Bücher | `books.vertical` |
  | Gelesen | `checkmark` |
  | Ungelesen | `circle.badge.exclamationmark` bzw. eigener Pfad |
  | Bewertet | `star` |
  | Import | `arrow.down.to.line` |
  | Suche | `magnifyingglass` |
  | Seitenleiste | `sidebar.left` |
  | Zoom | `minus` / `plus` |
  | Grid / Liste | `square.grid.2x2` / `list.bullet` |
  | Hinzufügen | `plus` |
  | Statistik-Chevron | `chevron.down` |

- **Cover:** im Prototyp Platzhalterverläufe (12 Juwelentöne, siehe `TOKENS.md`), weil keine Bilddaten vorlagen. Die App lädt echte Cover aus dem bestehenden Bestand; der Verlauf bleibt der Fallback für Bücher ohne Bild.
- **Beispieldaten:** die 1.800 Titel/Autoren im Prototyp sind generiert und dienen nur der Dichte-Prüfung.

---

## 10 · Dateien in diesem Bündel

| Datei | Inhalt |
|---|---|
| `TOKENS.md` | Design-Tokens, vollständig (Quelle der Wahrheit) |
| `mockup/index.html` | lauffähige Klick-Simulation, eine Datei, offline, ohne externe Abhängigkeiten — **die verbindliche Verhaltensreferenz** |
| `LibraryCompass.dc.html` | Quelldatei des Prototyps (Template + Logik), falls Werte im Detail nachgelesen werden sollen |
| `LibraryCompass v1 (hell, neutral).dc.html` | verworfene erste Richtung, nur zum Vergleich — **nicht** umsetzen |

Zum Durchklicken `mockup/index.html` in Safari oder Chrome öffnen. Alle in Abschnitt 6 genannten Interaktionen sind dort real bedienbar; Dunkel-/Hellmodus über den Toolbar-Button oder die Systemeinstellung.

---

## 11 · Abnahmekriterien

1. Funktionsumfang identisch zum Prototyp — kein Feature dazu, keins weg.
2. Suche und Sortierung reagieren bei 1.800 Büchern unmittelbar; keine Animation verzögert eine Eingabe, alle Transitions ≤ 150 ms.
3. Die Listenansicht zeigt in jeder Zeile ein Cover-Thumbnail.
4. Kein horizontales Scrollen, keine Layout-Sprünge beim Wechsel Grid ↔ Liste, beim Klappen der Seitenleiste, beim Klappen der Statistik oder beim Zoomen.
5. Bei Seitenleiste 400 + offenem Detail-Panel kürzen alle Statistik-Karten ihren Inhalt, statt ihn zu beschneiden oder zu überlaufen.
6. Hell- und Dunkelmodus folgen der Systemeinstellung und lassen sich zusätzlich manuell umschalten.
7. Zwei schnelle Klicks auf „+" ergeben zwei Zoom-Schritte.
