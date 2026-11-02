#!/bin/bash
# Builds build/Moffo.app (ad-hoc signed), and build/Moffo.dmg with --dmg.
# Usage: [VERSION=0.1.7] ./scripts/build-app.sh [--dmg]
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Moffo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Moffo "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
if [ -n "${VERSION:-}" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
fi
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--dmg" ]; then
  # drag-to-install image: the app next to a shortcut to /Applications
  STAGE=build/dmg
  rm -rf "$STAGE" build/Moffo.dmg
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname Moffo -srcfolder "$STAGE" -format UDZO -ov build/Moffo.dmg
  rm -rf "$STAGE"
  echo "Built build/Moffo.dmg"
fi
