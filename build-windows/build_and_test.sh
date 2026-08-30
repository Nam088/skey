#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT_DIR/build-windows/validate_contracts.py"
python3 "$ROOT_DIR/build-windows/run_typing_vectors.py"

if command -v cmake >/dev/null 2>&1; then
    BUILD_DIR="${SKEY_BUILD_DIR:-$ROOT_DIR/out/windows-contract}"
    cmake -S "$ROOT_DIR/build-windows" -B "$BUILD_DIR" -DSKEY_BUILD_TESTS=ON
    cmake --build "$BUILD_DIR"
    ctest --test-dir "$BUILD_DIR" --output-on-failure
else
    echo "cmake not installed; contract validation completed"
fi
