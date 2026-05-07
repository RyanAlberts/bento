#!/usr/bin/env bash
# Package Bento.app into a DMG users can drag into Applications.
#
# Usage:  ./scripts/build-dmg.sh [version]
# Output: ./build/Bento-v<version>.dmg

set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Bento.app"
DMG="$BUILD_DIR/Bento-v$VERSION.dmg"
STAGE="$BUILD_DIR/dmg-stage"

if [ ! -d "$APP" ]; then
    echo "→ Bento.app not found, building first…"
    "$ROOT/scripts/build-app.sh" release
fi

echo "→ staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "→ creating $DMG"
hdiutil create \
    -volname "Bento $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"
echo "✓ built $DMG ($(du -h "$DMG" | cut -f1))"
