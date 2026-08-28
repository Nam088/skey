#!/usr/bin/env bash
# release.sh — Build, package, and prepare SKey for GitHub Release + Homebrew Cask
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-1.0.0}"
APP_BUNDLE="$SCRIPT_DIR/SKey.app"
DIST_DIR="$SCRIPT_DIR/dist"
ZIP_NAME="SKey-$VERSION.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "==> Building SKey v$VERSION..."
bash "$SCRIPT_DIR/build.sh" --release

echo "==> Packaging SKey.app into $ZIP_NAME..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# ditto preserves resource forks, symlinks, and extended attributes
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "==> Done!"
echo "    File   : $ZIP_PATH"
echo "    SHA256 : $SHA256"
echo "    Version: $VERSION"
echo ""
echo "==> Next steps:"
echo "    1. Create GitHub Release v$VERSION at https://github.com/Nam088/skey/releases/new"
echo "    2. Upload: $ZIP_PATH"
echo "    3. Update homebrew-skey Cask with:"
echo "       url    \"https://github.com/Nam088/skey/releases/download/v$VERSION/$ZIP_NAME\""
echo "       sha256 \"$SHA256\""
