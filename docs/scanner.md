# Kamera-Scan — Aufbau, Fallen, Diagnose

Stand 2026-08-06, alles live auf dem Mac Studio erarbeitet. Diese Datei ist die
as-built-Doku des Strichcode-Scanners — inklusive der drei Fallen, die zusammen
einen ganzen Tag Fehlersuche gekostet haben. Wer hier etwas ändert: erst lesen.

## Bedienung

- **⌘K** oder Menü → „Buch scannen …", alternativ der „Scannen"-Knopf im ISBN-Dialog (⌘N).
- Strichcode der Buchrückseite 25–40 cm vor die Kamera (Mac-Webcams haben keinen Autofokus).
- Jede erkannte ISBN piept einmal und legt das Buch an — derselbe Weg wie die
  Handeingabe, inklusive Dublettenschutz und Metadaten-Lookup.
- Mehrere Bücher nacheinander sind möglich; der Dialog zählt mit.
- **iPhone als Kamera (empfohlen):** gesperrt neben den Mac legen, Bluetooth + WLAN an,
  gleiche Apple-ID. Es erscheint in der Kameraliste und wird wegen Autofokus automatisch
  bevorzugt. Erscheint es nicht sofort: liegen lassen, „Neu suchen" drücken.

## Architektur

| Baustein | Ort | Aufgabe |
|---|---|---|
| `ScannedCode` | Core | Entscheidet, ob ein Code ein Buch ist: EAN-13 nur mit Präfix 978/979 **und** gültiger Prüfziffer, ISBN-10 mit Prüfziffer, ISBN aus QR-Texten. Ohne diese Prüfung wird die EAN einer Müslipackung zum Buch. |
| `CameraChoice` | Core | Rangfolge bei mehreren Kameras: Autofokus > Auflösung, virtuelle Kameras (obs/virtual/snap/mmhmm/pickle/camo/epoccam) zuletzt — sie liefern kein Kamerabild. |
| `BarcodeScanner` | App | AVCaptureSession + **Vision** (`VNDetectBarcodesRequest`, alle 200 ms ein Frame). Beobachtet Kamera-An/Abstecken und wechselt selbst auf eine bessere Kamera. |
| `ScanSheet` | App | Dialog: Live-Bild, Kamerawahl, „Neu suchen", Zähler der erfassten Bücher. |

## Die drei Fallen (alle live erlebt)

### 1. TCC-Kamerarecht stirbt bei jedem Neubau

**Symptom:** „Kamera wird nicht erkannt" — real zeigt der Dialog „Kein Zugriff auf die
Kamera", und macOS fragt **nie wieder** nach.

**Mechanik:** Die App ist ad-hoc signiert; jeder Build erzeugt einen neuen Code-Hash.
macOS bindet das erteilte Kamerarecht an die Signatur und verweigert nach dem nächsten
Build **still** — `requestAccess` liefert sofort `false`, ohne Systemdialog.

**Fix:** `install-app.sh` setzt das Recht bei jeder Installation zurück
(`tccutil reset Camera de.storymaster.librarycompass`) — beim nächsten Scan fragt macOS
wieder. Gilt als Regel für **alle** ad-hoc-signierten Apps mit TCC-Rechten.

### 2. Die Kameraliste ist eine Momentaufnahme

**Symptom:** iPhone fehlt in der Liste, obwohl es bereitliegt und FaceTime es sieht.
Beweis-Experiment: USB-Kamera einstecken → iPhone erscheint **im selben Moment** mit.

**Mechanik:** Continuity-Kameras melden sich oft erst **nach** dem Öffnen des Dialogs an.
Wer die `DiscoverySession` nur einmal liest, verpasst sie. Ein beliebiges
Connect-Ereignis stößt die Neu-Anmeldung an.

**Fix:** Beobachter auf `AVCaptureDevice.wasConnected/wasDisconnected`; bei einer neu
erschienenen besseren Kamera (Autofokus) wechselt der Scanner selbst. Dazu der Knopf
„Neu suchen" und ein Hinweis, wenn nur virtuelle Kameras da sind.

### 3. `AVCaptureMetadataOutput` erkennt bei USB-Webcams nichts

**Symptom:** Bild scharf, aber kein Code wird je erkannt.

**Mechanik:** `availableMetadataObjectTypes` bleibt bei der USB-Webcam dieser Maschine
**leer** — vor `commitConfiguration`, danach und nach `startRunning` (gemessen). Wer die
gewünschten Typen gegen diese Liste filtert, aktiviert null Codetypen.

**Fix:** Frames per `AVCaptureVideoDataOutput` an **Vision** geben
(`VNDetectBarcodesRequest`, Symbologien EAN-13/EAN-8/UPC-E/QR). Vision hängt nicht an
den Kamera-Metadaten und verträgt leichte Unschärfe besser. VisionKits
`DataScannerViewController` gibt es auf macOS nicht.

## Diagnose-Werkzeuge

- **Scan-Dialog per Screenshot selbst ansehen** (ohne Nutzer als Messgerät):
  ```bash
  ./LibraryCompass.app/Contents/MacOS/LibraryCompass --state scan --screenshot /tmp/scan.png
  ```
- **Rechte-Status und Kameraliste** loggt der Scanner beim Start per `NSLog` — bei
  CLI-Start direkt auf stderr, sonst:
  ```bash
  log show --last 5m --info --predicate 'eventMessage CONTAINS "LibraryCompass"'
  ```
  Status: 0 = unbestimmt, 2 = verweigert, 3 = erlaubt. Wichtig: Der Status-Log steht
  **vor** dem Rechte-Check — dahinter schweigt er bei Verweigerung.
- **Kamerarecht von Hand zurücksetzen:**
  ```bash
  tccutil reset Camera de.storymaster.librarycompass
  ```
- Kein Logeintrag aus einer Routine = die Routine läuft nicht. Diese Frage („kommt der
  Code überhaupt an?") gehört an den **Anfang** jeder Fehlersuche — ⌘K war z. B. durch
  einen Menü-Fehler zeitweise gar nicht belegt (`CommandGroup(replacing:)` und
  `after:` auf derselben Gruppe schließen sich aus).

## Startschalter der App

| Schalter | Wirkung |
|---|---|
| `--state scan\|isbn\|import\|list\|detail\|empty\|wide\|nostats` | Startzustand (In-Memory-Demodaten bei `--screenshot`/`--uitest`) |
| `--screenshot <pfad>` | PNG des Fensters, dann Ende |
| `--fetch-covers` | Cover-Nachlauf über den echten Bestand, dann Ende |
| `--mark-read` | Gelesen-Datum = Erfassungsdatum für alle ohne Datum, dann Ende |
| `--export <pfad>` | CSV-Export des echten Bestands, dann Ende |

⚠️ Pflegeläufe (`--fetch-covers`, `--mark-read`, `--export`) nur bei **geschlossener**
App — gleicher SwiftData-Store. Vorher: `pgrep -f "LibraryCompass.app/Contents/MacOS"`.
