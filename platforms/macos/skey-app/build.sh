#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
APP_BUNDLE="$SCRIPT_DIR/SKey.app"
SYSTEM_APPLICATIONS="/Applications/SKey.app"

echo "==> 1. Building Rust libskey.a..."
cd "$REPO_DIR/core/skey-capi"
cargo build --release

LIBSKEY="$REPO_DIR/core/target/release/libskey.a"
if [[ ! -f "$LIBSKEY" ]]; then
    echo "Error: $LIBSKEY not found!"
    exit 1
fi

echo "==> 2. Preparing SKey.app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Dynamically stamp current version from git tag
# Only macOS tags. The repo also carries win-v* tags, and an unfiltered `git describe`
# picks whichever was cut last, which is how the About screen ended up announcing
# "Phiên bản win-v1.0.6" on a macOS build. Strip the prefix too: CFBundleShortVersionString
# must be a bare dotted version, or the update checker cannot parse its own version.
CURRENT_TAG="$(git describe --tags --abbrev=0 --match 'mac-v*' 2>/dev/null || echo "mac-v1.0.12")"
CURRENT_VERSION="${CURRENT_TAG#mac-v}"
CURRENT_VERSION="${CURRENT_VERSION#v}"
echo "==> Stamping version $CURRENT_VERSION into Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $CURRENT_VERSION" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CURRENT_VERSION" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

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

echo "==> 3. Compiling Swift files (Mode: $BUILD_MODE)..."
cd "$SCRIPT_DIR"

SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "$SCRIPT_DIR/Sources" -name "*.swift" -print0)

SWIFT_OPT_FLAGS=(-O -wmo)
if [[ "$BUILD_MODE" == "debug" ]]; then
    SWIFT_OPT_FLAGS=(-Onone)
fi

# Must match scripts/build_release.sh. Without an explicit -target, swiftc stamps the build
# host's OS version as the minimum, so a dev machine on a newer macOS silently produces a
# binary that will not launch on the versions we claim to support, and local testing then
# says nothing about what users receive.
MACOS_DEPLOYMENT_TARGET="14.0"
HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == "arm64" ]] || HOST_ARCH="x86_64"

swiftc "${SWIFT_OPT_FLAGS[@]}" \
    "${DEBUG_FLAG[@]}" \
    -target "${HOST_ARCH}-apple-macos${MACOS_DEPLOYMENT_TARGET}" \
    -import-objc-header "$SCRIPT_DIR/Support/BridgingHeader.h" \
    -I "$REPO_DIR/core/skey-capi/include" \
    -I "$SCRIPT_DIR/Sources/CSKey/include" \
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
