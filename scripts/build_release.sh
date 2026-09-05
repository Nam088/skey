#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
APP_DIR="$REPO_DIR/platforms/macos/skey-app"
TARGET_APP="$DIST_DIR/SKey.app"

echo "==> 1. Preparing clean dist directory..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> 2. Building Rust core library for aarch64 and x86_64..."
cd "$REPO_DIR/core/skey-capi"

# Add Apple targets if missing
rustup target add aarch64-apple-darwin x86_64-apple-darwin 2>/dev/null || true

cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

mkdir -p "$REPO_DIR/core/target/universal"
lipo -create \
    "$REPO_DIR/core/target/aarch64-apple-darwin/release/libskey.a" \
    "$REPO_DIR/core/target/x86_64-apple-darwin/release/libskey.a" \
    -output "$REPO_DIR/core/target/universal/libskey.a"

LIBSKEY="$REPO_DIR/core/target/universal/libskey.a"
echo "Universal libskey.a created successfully:"
lipo -info "$LIBSKEY"

echo "==> 3. Generating AppIcon..."
cd "$APP_DIR"
swift scripts/generate_app_icon.swift

echo "==> 4. Building Universal SKey.app bundle..."
rm -rf "$TARGET_APP"
mkdir -p "$TARGET_APP/Contents/MacOS"
mkdir -p "$TARGET_APP/Contents/Resources"

cp "$APP_DIR/Resources/Info.plist" "$TARGET_APP/Contents/Info.plist"

if [[ -n "${APP_VERSION:-}" ]]; then
    echo "==> Stamping version $APP_VERSION into Info.plist..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
fi

if [[ -d "$APP_DIR/Resources/vi.lproj" ]]; then
    cp -R "$APP_DIR/Resources/vi.lproj" "$TARGET_APP/Contents/Resources/"
fi
if [[ -d "$APP_DIR/Resources/en.lproj" ]]; then
    cp -R "$APP_DIR/Resources/en.lproj" "$TARGET_APP/Contents/Resources/"
fi
if [[ -f "$APP_DIR/Resources/Localizable.xcstrings" ]]; then
    cp "$APP_DIR/Resources/Localizable.xcstrings" "$TARGET_APP/Contents/Resources/"
fi
if [[ -f "$APP_DIR/Resources/AppIcon.icns" ]]; then
    cp "$APP_DIR/Resources/AppIcon.icns" "$TARGET_APP/Contents/Resources/"
fi

SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "$APP_DIR/Sources" -name "*.swift" -print0)

# Deployment target vs SDK are two separate dials, and conflating them shipped a broken
# binary once already: `-target ...macos26.0` on a macOS 14 runner produced `minos 26.0,
# sdk 14.5`, an app that refused to launch below macOS 26 yet was built against the old SDK
# so it never got Liquid Glass either. Keep this at the oldest macOS we support; the SDK
# comes from whichever Xcode the runner selects, and building against the macOS 26 SDK is
# what grants Liquid Glass on macOS 26 regardless of the value below.
MACOS_DEPLOYMENT_TARGET="14.0"

# Compile arm64 binary
swiftc -O -wmo \
    -target "arm64-apple-macos${MACOS_DEPLOYMENT_TARGET}" \
    -import-objc-header "$APP_DIR/Support/BridgingHeader.h" \
    -I "$REPO_DIR/core/skey-capi/include" \
    "${SWIFT_FILES[@]}" \
    "$REPO_DIR/core/target/aarch64-apple-darwin/release/libskey.a" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -framework SwiftUI \
    -framework CryptoKit \
    -lsqlite3 \
    -o "$DIST_DIR/SKey_arm64"

# Compile x86_64 binary
swiftc -O -wmo \
    -target "x86_64-apple-macos${MACOS_DEPLOYMENT_TARGET}" \
    -import-objc-header "$APP_DIR/Support/BridgingHeader.h" \
    -I "$REPO_DIR/core/skey-capi/include" \
    "${SWIFT_FILES[@]}" \
    "$REPO_DIR/core/target/x86_64-apple-darwin/release/libskey.a" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -framework SwiftUI \
    -framework CryptoKit \
    -lsqlite3 \
    -o "$DIST_DIR/SKey_x86_64"

# Create Universal macOS binary
lipo -create "$DIST_DIR/SKey_arm64" "$DIST_DIR/SKey_x86_64" -output "$TARGET_APP/Contents/MacOS/SKey"
rm -f "$DIST_DIR/SKey_arm64" "$DIST_DIR/SKey_x86_64"

echo "Universal binary created successfully:"
lipo -info "$TARGET_APP/Contents/MacOS/SKey"

echo "==> 5. Ad-hoc / Developer Code Signing..."
codesign --force --deep --sign - "$TARGET_APP"

echo "==> 6. Creating DMG Installer..."
bash "$REPO_DIR/scripts/create_dmg.sh"

echo "==> 7. Creating ZIP Archive..."
cd "$DIST_DIR"
zip -r -y "SKey-macOS-Universal.zip" "SKey.app"

echo "==> 8. Generating SHA256 Checksums..."
shasum -a 256 "SKey-Installer.dmg" "SKey-macOS-Universal.zip" > "SHA256SUMS.txt"
cat "SHA256SUMS.txt"

echo "=========================================="
echo "SUCCESS: All release assets packaged in $DIST_DIR"
echo "=========================================="
