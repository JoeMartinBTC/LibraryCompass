#!/usr/bin/env bash
# Google-Books-Schlüssel hinterlegen und sofort live prüfen.
# Anleitung zum Beschaffen: docs/google-books-key.md
set -euo pipefail

KEY="${1:-}"
if [ -z "$KEY" ]; then
  echo "Aufruf: ./set-google-key.sh <API-KEY>"
  echo "Woher der Schlüssel kommt: docs/google-books-key.md"
  exit 1
fi

DIR="$HOME/Library/Application Support/LibraryCompass"
FILE="$DIR/google-books-key.txt"

echo "Prüfe Schlüssel gegen die Books API …"
PROBE=$(curl -s -w '\n%{http_code}' --max-time 20 \
  "https://www.googleapis.com/books/v1/volumes?q=isbn:9780345391803&key=$KEY")
STATUS=$(printf '%s' "$PROBE" | tail -1)
BODY=$(printf '%s' "$PROBE" | sed '$d')

if [ "$STATUS" != "200" ]; then
  echo "HTTP $STATUS — Schlüssel nicht übernommen."
  printf '%s\n' "$BODY" | head -20
  echo "400 = Schlüssel ungültig · 403 = Books API im Projekt nicht aktiviert · 429 = Kontingent erschöpft"
  exit 1
fi

TITLE=$(printf '%s' "$BODY" | /usr/bin/python3 -c \
  'import json,sys; d=json.load(sys.stdin); print(d.get("items",[{}])[0].get("volumeInfo",{}).get("title","(ohne Titel)"))' 2>/dev/null || echo "(Titel nicht gelesen)")
echo "HTTP 200 · Testtreffer: $TITLE"

mkdir -p "$DIR"
printf '%s' "$KEY" > "$FILE"
chmod 600 "$FILE"
echo "Hinterlegt: $FILE (nur für dich lesbar)"
echo "App neu starten, damit der Schlüssel gelesen wird."
