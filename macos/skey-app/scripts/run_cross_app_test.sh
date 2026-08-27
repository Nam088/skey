#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/tmp/cross_app_test_bin"

echo "==> Compiling Cross-App Isolation Tester..."
swiftc -parse-as-library "$SCRIPT_DIR/cross_app_switch_tester.swift" -o "$BIN_PATH"

echo "==> Running Cross-App Isolation Tester..."
"$BIN_PATH"
