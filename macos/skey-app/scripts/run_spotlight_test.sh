#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/tmp/spotlight_typing_tester_bin"

echo "==> Compiling Spotlight Typing Benchmark..."
swiftc -parse-as-library "$SCRIPT_DIR/spotlight_typing_tester.swift" -o "$BIN_PATH"

echo "==> Running Spotlight Typing Benchmark..."
"$BIN_PATH"
