#!/bin/bash
# Builds build/Moffo.app (ad-hoc signed). Usage: ./scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Moffo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Moffo "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
