#!/usr/bin/env bash
# Build Bento.app — wraps the SPM-built binaries into a proper macOS .app bundle
# and ad-hoc-signs it so Gatekeeper won't bounce a freshly-built copy.
#
# Usage:  ./scripts/build-app.sh [debug|release]
# Output: ./build/Bento.app

set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Bento.app"
BIN_SRC="$ROOT/.build/$CONFIG"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

echo "→ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_SRC/Bento"     "$APP/Contents/MacOS/Bento"
cp "$BIN_SRC/bentocli"  "$APP/Contents/MacOS/bentocli"
cp "$ROOT/Sources/Bento/Resources/Info.plist" "$APP/Contents/Info.plist"

# PkgInfo so Launch Services treats this as a real app
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ ad-hoc codesigning (Gatekeeper-friendly)"
codesign --force --sign - --deep "$APP"

# Strip any quarantine attribute that may have hitched a ride
xattr -cr "$APP" 2>/dev/null || true

echo "✓ built $APP"
echo "  Bento app:  $(du -h "$APP/Contents/MacOS/Bento" | cut -f1)"
echo "  bento CLI:  $(du -h "$APP/Contents/MacOS/bentocli" | cut -f1)"
