#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/validate_contracts.py"
python3 "$SCRIPT_DIR/run_typing_vectors.py"

if command -v cmake >/dev/null 2>&1; then
    BUILD_DIR="${SKEY_BUILD_DIR:-$ROOT_DIR/out/windows-contract}"
    cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -DSKEY_BUILD_TESTS=ON
    cmake --build "$BUILD_DIR"
    ctest --test-dir "$BUILD_DIR" --output-on-failure
else
    echo "cmake not installed; contract validation completed"
fi
