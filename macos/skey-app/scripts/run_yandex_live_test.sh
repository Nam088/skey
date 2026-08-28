#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/tmp/yandex_live_test_bin"

echo "==> Compiling Yandex Live Tester..."
swiftc -parse-as-library "$SCRIPT_DIR/yandex_live_test.swift" -o "$BIN_PATH"

echo "==> Truncating /tmp/skey.log to capture fresh live events..."
> /tmp/skey.log

echo "==> Running Yandex Live Tester (Opening Yandex and typing live)..."
"$BIN_PATH"

echo ""
echo "=================================================================="
echo "==> SKey Live Logs during Yandex interaction:"
echo "=================================================================="
cat /tmp/skey.log
echo "=================================================================="
