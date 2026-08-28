#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_BUNDLE="$SCRIPT_DIR/SKey.app"
SYSTEM_APPLICATIONS="/Applications/SKey.app"

echo "==> 1. Building Rust libskey.a..."
cd "$REPO_DIR/port/skey-capi"
cargo build --release

LIBSKEY="$REPO_DIR/port/target/release/libskey.a"
if [[ ! -f "$LIBSKEY" ]]; then
    echo "Error: $LIBSKEY not found!"
    exit 1
fi

echo "==> 2. Preparing SKey.app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy localization resources (.lproj, .xcstrings, etc.)
if [[ -d "$SCRIPT_DIR/Resources/vi.lproj" ]]; then
    cp -R "$SCRIPT_DIR/Resources/vi.lproj" "$APP_BUNDLE/Contents/Resources/"
fi
if [[ -d "$SCRIPT_DIR/Resources/en.lproj" ]]; then
    cp -R "$SCRIPT_DIR/Resources/en.lproj" "$APP_BUNDLE/Contents/Resources/"
fi
if [[ -f "$SCRIPT_DIR/Resources/Localizable.xcstrings" ]]; then
    cp "$SCRIPT_DIR/Resources/Localizable.xcstrings" "$APP_BUNDLE/Contents/Resources/"
fi
if [[ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

BUILD_MODE="release"
DEBUG_FLAG=()

for arg in "$@"; do
    case "$arg" in
        --debug|--dev)
            BUILD_MODE="debug"
            DEBUG_FLAG=("-D" "DEBUG")
            ;;
        --release)
            BUILD_MODE="release"
            DEBUG_FLAG=()
            ;;
    esac
done

echo "==> 3. Compiling Swift files (Mode: $BUILD_MODE, WMO)..."
cd "$SCRIPT_DIR"

SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "$SCRIPT_DIR/Sources" -name "*.swift" -print0)

swiftc -O -wmo \
    "${DEBUG_FLAG[@]}" \
    -import-objc-header "$SCRIPT_DIR/Support/BridgingHeader.h" \
    -I "$REPO_DIR/port/skey-capi/include" \
    "${SWIFT_FILES[@]}" \
    "$LIBSKEY" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -framework SwiftUI \
    -framework CryptoKit \
    -lsqlite3 \
    -o "$APP_BUNDLE/Contents/MacOS/SKey"

echo "==> 4. Code signing SKey.app with trusted certificate SKeyDev..."
codesign --force --deep --sign "SKeyDev" "$APP_BUNDLE"

echo "==> 5. Installing to /Applications/SKey.app..."
rm -rf "$SYSTEM_APPLICATIONS"
cp -R "$APP_BUNDLE" "$SYSTEM_APPLICATIONS"

echo "==> Done! Successfully built and installed: $SYSTEM_APPLICATIONS"
