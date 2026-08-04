# LibraryCompass – Design-Tokens

Referenz: **CleanMyMac (MacPaw)** – App-UI. Tiefer violetter Verlaufshintergrund,
Glasflächen, weiche Glows, große leichte Typo, genau eine Hauptaktion pro Screen.

Quelle der Wahrheit für die SwiftUI-Umsetzung. Namen 1:1 übernehmen.
Im Mockup liegen alle Werte als CSS-Custom-Properties auf `:root` (dunkel = Standard)
bzw. `html[data-theme="light"]` und `@media (prefers-color-scheme: light)`.

## 1 · Hintergrund (die wichtigste Ebene)

Kein Flächenfarbton, sondern ein Verlaufsstapel. In SwiftUI als `ZStack` aus
`LinearGradient` + drei `RadialGradient` (Blend-Mode normal, Deckkraft wie unten).

**Dunkel — `bgLayers`**
| Ebene | Wert |
|---|---|
| Basis | `LinearGradient` 163°: `#28104E` 0 % → `#1B0C36` 55 % → `#150A2C` 100 % |
| Glow oben links | `RadialGradient` `#5A2497` → transparent, Zentrum 10 % / −12 %, Radius 120 % / 95 % |
| Glow oben rechts | `RadialGradient` `#2E3FA8` → transparent, Zentrum 97 % / 6 %, Radius 95 % / 80 % |
| Glow unten mitte | `RadialGradient` `#7A2A9E` → transparent, Zentrum 60 % / 108 %, Radius 70 % / 60 % |

**Hell — `bgLayers`**
| Ebene | Wert |
|---|---|
| Basis | `LinearGradient` 163°: `#FAF7FF` → `#F3EEFD` |
| Glow oben links | `#E5D6FF` → transparent |
| Glow oben rechts | `#D9E3FF` → transparent |
| Glow unten mitte | `#F0DAFB` → transparent |

## 2 · Farben

| Token | Dunkel | Hell | Verwendung |
|---|---|---|---|
| `sidebar` | `rgba(12,5,28,.34)` | `rgba(255,255,255,.44)` | Sidebar + Detail-Panel (über `bgLayers`, mit `blur 24`) |
| `glass` | `rgba(255,255,255,.055)` | `rgba(255,255,255,.66)` | Karten, Suchfeld, Chips, Segmented |
| `glass2` | `rgba(255,255,255,.10)` | `rgba(255,255,255,.86)` | Aktiver Zustand, Eingabefelder, Sheets |
| `glass3` | `rgba(255,255,255,.16)` | `rgba(124,70,200,.10)` | Balken-Spuren, leere Sterne |
| `brd` | `rgba(255,255,255,.11)` | `rgba(74,38,124,.12)` | 1-px-Kanten aller Glasflächen |
| `brd2` | `rgba(255,255,255,.20)` | `rgba(74,38,124,.20)` | Kante Sheets / Auswahl-Ring |
| `text` | `#FFFFFF` | `#1E1136` | Primärtext |
| `text2` | `rgba(255,255,255,.66)` | `rgba(30,17,54,.62)` | Sekundärtext, Labels |
| `text3` | `rgba(255,255,255,.40)` | `rgba(30,17,54,.40)` | Zähler, Metadaten, Platzhalter |
| `accent` | `#B45CFF` | `#8B3FE0` | Hauptaktion, Fortschritt |
| `accent2` | `#7B3BE8` | `#6A29C4` | Zweiter Stop des Aktions-Verlaufs (150°) |
| `accentInk` | `#FFFFFF` | `#FFFFFF` | Text auf Aktion |
| `cyan` | `#4FD8E8` | `#1F9BB0` | Fortschritt-Start, Import |
| `mint` | `#56E39F` | `#1E9E6A` | „gelesen“, positive Delta |
| `gold` | `#FFC24F` | `#C8892A` | Sternebewertung |
| `pink` | `#FF6BC1` | `#D4459B` | Verteilungsbalken, Genre-Marker |
| `scrim` | `#150A2C` 0 → .50 → .82 | `#F8F5FF` 0 → .62 → .92 | 112 px Verlauf unter dem Floating-Button |

**Genre-Marker** (8 px, `cornerRadius 3`, Glow `0 0 10 self`):
`#B45CFF #4FD8E8 #FF6BC1 #FFC24F #6BA8FF #56E39F #FF8A6B #A0E85C #C36BFF #3AC8E0`

**Cover-Platzhalter** — Verlauf 150°, je Buch aus der ID abgeleitet, 12 Paare:
`#8B5CF6→#3B1A8E` · `#FF6B9D→#8E2A63` · `#3AC8E0→#175E8C` · `#FFB347→#B8531A` ·
`#56E39F→#177A5A` · `#C36BFF→#5B1E9E` · `#FF8A6B→#A83A5C` · `#6BA8FF→#243E9E` ·
`#E8C24F→#8A6516` · `#FF6BC1→#6E1E8E` · `#4FD8E8→#2E3FA8` · `#A0E85C→#3E7A18`

Darüber immer zwei Overlays, damit die weiße Titelschrift auf jedem Tint trägt:
Glanz `linear 200°: rgba(255,255,255,.20) → transparent 40 %` und
Lesbarkeit `linear 180°: rgba(0,0,0,.30) → transparent 38 % → transparent 66 % → rgba(0,0,0,.30)`.
Ein echtes Cover ersetzt nur den Verlauf, die Overlays bleiben.

**Sidebar-Icon-Tiles** (26 px, `cornerRadius 9`, Verlauf 150°, Schatten `0 3 10 g2`):
Alle Bücher `#B45CFF / 55 % #7B3BE8` · Gelesen `#56E39F / 55 % #177A5A` ·
Ungelesen `#FFB347 / 55 % #B8531A` · Bewertet `#FFC24F / 55 % #8A6516`

## 3 · Typografie

SF Pro (`-apple-system`). **Große Zahlen und Titel bewusst leicht** (Weight 300/400) —
das ist der zentrale CleanMyMac-Ton. Tracking ab 20 pt negativ.

| Token | Größe / Weight / Tracking | Verwendung |
|---|---|---|
| `screenTitle` | 36 / 300 / −0.03em | Screen-Titel („Alle Bücher“, Genre-Name) |
| `heroNumber` | 32 / 300 / −0.03em | Große Zahl („1.800“) |
| `statNumber` | 28 / 300 / −0.03em | Zahl in Statistik-Karten |
| `ringValue` | 20 / 400 / −0.02em | Prozent im Ring |
| `detailTitle` | 21 / 400 / −0.02em | Buchtitel im Detail-Panel |
| `sheetTitle` | 17–18 / 500 / −0.01em | Dialog-Titel |
| `action` | 14.5 / 500 | Floating-Button |
| `bodyM` | 13.5 / 450–560 | Sidebar-Zeilen |
| `body` | 13 / 450 | Standard-UI, Listen- und Grid-Titel |
| `caption` | 12–12.5 / 450 | Genre, Jahr, Kartenlabels, Hilfetexte |
| `captionS` | 11–11.5 / 450 | Autor, Zähler, Datum, ISBN |
| `label` | 10–10.5 / 700 / +0.09em / UPPERCASE | Abschnittslabels („GENRES“, „DETAILS“) |
| `coverTitle` | 13 / 600, Schatten `0 1 3 rgba(0,0,0,.25)` | Titel auf dem Platzhalter-Cover |
| `coverAuthor` | 8.5 / 600 / +0.11em / UPPERCASE | Autor auf dem Cover |

Zahlen immer `tabular-nums`, Formatierung `de-DE` („1.800“, „Ø 3,6“, „09.08.2026“).

## 4 · Radien

| Token | Wert | Verwendung |
|---|---|---|
| `rXS` | 3–4 | Listen-Thumbnail, Genre-Marker |
| `rS` | 9 | Icon-Tiles, Chips |
| `rM` | 10–11 | Suchfeld, Select, Eingaben, Cover im Grid |
| `rL` | 12–14 | Sekundär-Buttons, Cover im Detail-Panel |
| `rCard` | 20 | Statistik-Karten |
| `rSheet` | 24 | Dialoge |
| `rPill` | 26 (= Höhe/2) | Floating-Hauptaktion |
| `rWindow` | 14 | Fensterrahmen |
| `rRow` | 13 | Listenzeile |
| `rTile` | 18 | Auswahl-Fläche einer Grid-Karte |

Cover-Verhältnis immer **2 : 3**.

## 5 · Unschärfe & Schatten

| Token | Wert | Verwendung |
|---|---|---|
| `blurChrome` | 24 | Sidebar, Detail-Panel |
| `blurCard` | 18–20 | Karten, Suchfeld, Select |
| `blurSheet` | 40 (Sheet) · 8 (Overlay) | Dialog + Hintergrund-Overlay |
| `glow` | `0 0 0 1 rgba(255,255,255,.14)` + `0 14 40 rgba(180,92,255,.38)` | Floating-Aktion, Empty-State-Icon |
| `shadowCard` | `0 2 6 rgba(0,0,0,.22)` + `0 18 44 rgba(0,0,0,.30)` | Statistik-Karten |
| `shadowCover` | `0 3 10 rgba(0,0,0,.34)` + `0 14 34 rgba(0,0,0,.34)` | Cover, Thumbnails |
| `shadowSheet` | `0 30 80 rgba(0,0,0,.62)` | Dialoge, großes Cover |
| `shadowWindow` | `0 40 90 rgba(0,0,0,.55)` | Fenster |
| `ringGlow` | `0 0 26 rgba(180,92,255,.34)` | Fortschrittsring |
| `starGlow` | `0 0 12 rgba(255,194,79,.55)` | gesetzter Stern |

Hell: gleiche Geometrie, Alpha deutlich niedriger (`.06–.34`, Farbe `rgba(40,16,78,…)`),
`glow` mit weißer Innenkante `rgba(255,255,255,.6)`.

## 6 · Spacing (4-pt-Raster)

| Token | Wert | Verwendung |
|---|---|---|
| `s1` | 4 | Icon-Abstände, Balkenabstand |
| `s2` | 8 | Buttons, Chips |
| `s3` | 12 | Sidebar-Innenabstand, Kartenlücke (14) |
| `s4` | 16 | Karten-Padding vertikal, Blockabstände |
| `s5` | 20 | Karten-Padding horizontal, Panel-Blöcke |
| `s6` | 26 | Seitenrand Inhalt |
| `s7` | 28 | Dialog-Padding |
| `gridGap` | 26 vertikal / 20 horizontal | Cover-Grid |

## 7 · Maße

| Token | Wert |
|---|---|
| `sidebarWidth` | 252 (Standard, ziehbar 180–400, zuklappbar) |
| `sidebarHandle` | 7 (Ziehfläche, 3 px über die Kante) |
| `detailWidth` | 352 |
| `titlebarHeight` | 54 |
| `toolbarHeight` | 54 |
| `statRowHeight` | ≈ 170 (Inhalt) |
| `rowHeight` | 58 (Liste) |
| `thumbSize` | 34 × 50 |
| `coverMinWidth` | 146 × `zoom` |
| `zoom` | 0,70–1,70, Schritt 0,10 (Standard 1,00) – skaliert Cover-Breite, Listen-Zeilenhöhe (58 × zoom) und Thumbnail (34 × 50 × zoom) |
| `ringSize` | 84, Ringbreite 7 |
| `controlHeight` | 32 (Toolbar) · 33 (Panel) · 36 (Dialog) · 52 (Floating-Aktion) |
| `scrimHeight` | 112 |
| `actionBottomInset` | 26 |

## 8 · Bewegung

| Token | Wert | Verwendung |
|---|---|---|
| `hover` | 120 ms ease | Hintergrund, Farbe, Ring, Glow |
| `progress` | 140 ms linear | Import-Balken |
| `sheetIn` | 120 ms ease-out, `y −10 → 0`, `scale .985 → 1` | Dialog |

Sidebar-Breite, Zuklappen und Zoom ändern die Geometrie **ohne** Transition — Ziehen muss dem Cursor 1:1 folgen.

**Keine Transition auf Layout-Eigenschaften** (Größe, Position, Grid-Spalten).
Suche, Sortierung und der Wechsel Grid ↔ Liste schalten ohne Animation; das Grid
lädt in Blöcken von 60 Karten beim Scrollen nach. So reagiert die Ansicht bei
1.800 Büchern sofort und es gibt keine Layout-Sprünge.
