#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/tmp/spotlight_word_test_bin"

echo "==> Compiling Word-by-Word Test..."
swiftc -parse-as-library "$SCRIPT_DIR/spotlight_word_by_word_test.swift" -o "$BIN_PATH"

echo "==> Running Word-by-Word Test..."
"$BIN_PATH"
