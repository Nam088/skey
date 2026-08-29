#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "==> 1. Generating DMG background..."
swift scripts/generate_dmg_background.swift

DMG_TITLE="SKey"
DMG_NAME="SKey-Installer.dmg"
TEMP_DMG="dist/temp_${DMG_NAME}"
FINAL_DMG="dist/${DMG_NAME}"
DMG_ROOT="dist/dmg_root"

echo "==> 2. Preparing DMG staging directory..."
rm -rf "$TEMP_DMG" "$FINAL_DMG" "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
mkdir -p dist

echo "==> 3. Copying SKey.app and Applications symlink..."
if [[ -d "$REPO_DIR/dist/SKey.app" ]]; then
    cp -R "$REPO_DIR/dist/SKey.app" "$DMG_ROOT/"
elif [[ -d "$REPO_DIR/macos/skey-app/SKey.app" ]]; then
    cp -R "$REPO_DIR/macos/skey-app/SKey.app" "$DMG_ROOT/"
else
    echo "Error: SKey.app not found in dist/ or macos/skey-app/!"
    exit 1
fi

ln -s /Applications "$DMG_ROOT/Applications"

mkdir -p "$DMG_ROOT/.background"
if [[ -f "dist/.background/background.png" ]]; then
    cp "dist/.background/background.png" "$DMG_ROOT/.background/"
fi

echo "==> 4. Creating writable disk image..."
hdiutil create -srcfolder "$DMG_ROOT" -volname "$DMG_TITLE" -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200M "$TEMP_DMG"

echo "==> 5. Mounting disk image..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

echo "==> 6. Configuring Finder presentation properties..."
osascript <<EOF || true
tell application "Finder"
    tell disk "$DMG_TITLE"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {350, 180, 950, 560}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        
        set position of item "SKey.app" of container window to {140, 215}
        set position of item "Applications" of container window to {460, 215}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sync
sleep 2

echo "==> 6. Unmounting..."
hdiutil detach "$DEVICE" -force || true
sleep 1

echo "==> 7. Converting to compressed final DMG..."
rm -f "$FINAL_DMG"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
rm -f "$TEMP_DMG"
rm -rf "$DMG_ROOT"

echo "=========================================="
echo "SUCCESS: Installer DMG created at:"
echo "$REPO_DIR/$FINAL_DMG"
echo "=========================================="
