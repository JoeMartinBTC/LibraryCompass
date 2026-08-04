#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
[ -f build/AppIcon.icns ] || swift Scripts/generate_icon.swift
mkdir -p LibraryCompass.app/Contents/MacOS LibraryCompass.app/Contents/Resources
cp -f .build/release/LibraryCompass LibraryCompass.app/Contents/MacOS/LibraryCompass
cp -f Info-template.plist LibraryCompass.app/Contents/Info.plist
cp -f build/AppIcon.icns LibraryCompass.app/Contents/Resources/AppIcon.icns
printf 'APPL????' > LibraryCompass.app/Contents/PkgInfo
codesign --force --sign - --timestamp=none LibraryCompass.app
echo "Gebaut. Start: open LibraryCompass.app  ·  Installieren: ./install-app.sh"
