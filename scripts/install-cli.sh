#!/usr/bin/env bash
# Symlink the bentocli binary inside Bento.app to a friendlier `bento` name on PATH.
#
# Usage:  ./scripts/install-cli.sh

set -euo pipefail

APP="/Applications/Bento.app"
TARGET="/usr/local/bin/bento"

if [ ! -d "$APP" ]; then
    APP="$(cd "$(dirname "$0")/.." && pwd)/build/Bento.app"
    if [ ! -d "$APP" ]; then
        echo "Bento.app not found in /Applications or ./build. Build first." >&2
        exit 1
    fi
fi

mkdir -p "$(dirname "$TARGET")"
ln -sf "$APP/Contents/MacOS/bentocli" "$TARGET"
echo "✓ symlinked $TARGET → $APP/Contents/MacOS/bentocli"
echo "  Try: bento --version"
