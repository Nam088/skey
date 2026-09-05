#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Đường dẫn cố định: quyền Accessibility gắn theo đường dẫn binary,
# đổi path là phải cấp quyền lại.
BIN_PATH="/tmp/skey_texstudio_probe"

echo "==> Biên dịch TeXstudio inject probe..."
swiftc -parse-as-library "$SCRIPT_DIR/texstudio_inject_probe.swift" -o "$BIN_PATH"

echo "==> Chạy probe..."
echo ""
"$BIN_PATH" "$@"
