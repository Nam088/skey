#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/../.." && pwd)"
BIN_PATH="/tmp/test_app_exclusion_bin"

LIBSKEY="$REPO_DIR/core/target/release/libskey.a"

SWIFT_SOURCES=()
while IFS= read -r -d '' file; do
    # Exclude main.swift to avoid duplicate entry points
    if [[ "$(basename "$file")" != "main.swift" ]]; then
        SWIFT_SOURCES+=("$file")
    fi
done < <(find "$APP_DIR/Sources" -name "*.swift" -print0)

echo "==> 1. Compiling Test Suite with Whole Module..."
swiftc -O -wmo -D DEBUG \
    -import-objc-header "$APP_DIR/Support/BridgingHeader.h" \
    -I "$REPO_DIR/core/skey-capi/include" \
    "${SWIFT_SOURCES[@]}" \
    "$SCRIPT_DIR/test_app_exclusion_and_debug_security.swift" \
    "$LIBSKEY" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -framework SwiftUI \
    -framework CryptoKit \
    -lsqlite3 \
    -o "$BIN_PATH"

echo "==> 2. Executing Test Suite..."
"$BIN_PATH"
