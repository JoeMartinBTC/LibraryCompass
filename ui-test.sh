#!/bin/bash
set -e
cd "$(dirname "$0")"
xcodegen generate
xcodebuild test -project LibraryCompass.xcodeproj -scheme LibraryCompass -destination 'platform=macOS' \
  2>&1 | grep -E "Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)|error:"
