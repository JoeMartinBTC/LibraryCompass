#!/bin/bash
# Baut das Bundle und installiert es als anklickbare App in /Applications.
set -e
cd "$(dirname "$0")"
./make-app.sh
DEST="/Applications/LibraryCompass.app"
pkill -f "LibraryCompass.app/Contents/MacOS/LibraryCompass" 2>/dev/null || true
rsync -a --delete LibraryCompass.app/ "$DEST/"
codesign --force --sign - --timestamp=none "$DEST"   # nach rsync neu signieren
touch "$DEST"                                        # Finder/LaunchServices Icon-Cache anstupsen
# Ad-hoc-Signatur ändert sich mit jedem Build → macOS verwirft das erteilte
# Kamerarecht und verweigert STILL (kein neuer Dialog). Reset erzwingt die Frage.
tccutil reset Camera de.storymaster.librarycompass >/dev/null 2>&1 || true
echo "Installiert: $DEST (Kamerarecht wird beim nächsten Scan neu erfragt)"
