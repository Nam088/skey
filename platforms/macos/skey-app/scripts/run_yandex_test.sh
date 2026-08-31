#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/tmp/yandex_typing_tester_bin"

echo "==> Compiling Yandex Typing Tester..."
swiftc -parse-as-library "$SCRIPT_DIR/yandex_typing_tester.swift" -o "$BIN_PATH"

echo "==> Running Yandex Typing Tester..."
"$BIN_PATH"

echo "==> Tail of /tmp/skey.log:"
tail -n 25 /tmp/skey.log
