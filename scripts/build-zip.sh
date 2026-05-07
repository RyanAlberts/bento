#!/usr/bin/env bash
# Build the release ZIP that the npm postinstall script downloads.
# Wraps Bento.app into a flat ZIP using `ditto` (preserves resource forks
# and the ad-hoc signature).
#
# Usage:  ./scripts/build-zip.sh [version]
# Output: ./build/Bento-v<version>.zip

set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Bento.app"
ZIP="$BUILD_DIR/Bento-v$VERSION.zip"

if [ ! -d "$APP" ]; then
    echo "→ Bento.app not found, building first…"
    "$ROOT/scripts/build-app.sh" release
fi

echo "→ packaging $ZIP via ditto (signature-preserving)"
rm -f "$ZIP"
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent "Bento.app" "$ZIP"
echo "✓ built $ZIP ($(du -h "$ZIP" | cut -f1))"

# Print the SHA-256 so the npm package.json can pin it for integrity checking
echo "  sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
