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
echo "Installiert: $DEST"
