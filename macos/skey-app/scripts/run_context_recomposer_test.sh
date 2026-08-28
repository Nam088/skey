#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SOURCES_DIR="$SCRIPT_DIR/../Sources"
LIBSKEY="$REPO_DIR/port/target/release/libskey.a"
BIN_PATH="/tmp/context_recomposer_tester_bin"

echo "==> Compiling Context Recomposer & Web Isolation Safety Tester..."

SWIFT_SOURCES=(
    "$SCRIPT_DIR/context_recomposer_tester.swift"
    "$SOURCES_DIR/Features/Keyboard/Context/VietnameseDecomposer.swift"
    "$SOURCES_DIR/Features/Keyboard/Context/ContextRecomposer.swift"
    "$SOURCES_DIR/Features/Keyboard/Context/AccessibilityContextReader.swift"
    "$SOURCES_DIR/Features/Keyboard/Engine/SKeyEngine.swift"
    "$SOURCES_DIR/Features/Keyboard/Engine/InputMethod.swift"
    "$SOURCES_DIR/Features/Keyboard/EventHandling/KeyEventSender.swift"
    "$SOURCES_DIR/Features/Keyboard/EventHandling/KeyConstants.swift"
    "$SOURCES_DIR/Shared/Services/AppFocusObserver.swift"
    "$SOURCES_DIR/Shared/Settings/SettingsModule.swift"
    "$SOURCES_DIR/Shared/Settings/Modules/KeyboardSettings.swift"
    "$SOURCES_DIR/Shared/Settings/Modules/ClipboardSettings.swift"
    "$SOURCES_DIR/Shared/Settings/Modules/GeneralSettings.swift"
    "$SOURCES_DIR/Shared/Settings/AppSettings.swift"
    "$SOURCES_DIR/Shared/Logging/LogEntry.swift"
    "$SOURCES_DIR/Shared/Logging/LogStore.swift"
    "$SOURCES_DIR/Shared/Logging/SKeyLogger.swift"
)

swiftc -parse-as-library \
    -import-objc-header "$SCRIPT_DIR/../Support/BridgingHeader.h" \
    -I "$REPO_DIR/port/skey-capi/include" \
    "${SWIFT_SOURCES[@]}" \
    "$LIBSKEY" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -o "$BIN_PATH"

echo "==> Running Safety Tests..."
"$BIN_PATH"
