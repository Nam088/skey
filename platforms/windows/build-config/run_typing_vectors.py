#!/usr/bin/env python3
"""Replay shared vectors through the portable Rust CLI."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
METHODS = {"telex": "0", "vni": "1", "viqr": "2", "simpleTelex": "5"}


def main():
    vectors = json.loads((ROOT / "shared/typing-vectors/basic.json").read_text(encoding="utf-8"))["vectors"]
    for vector in vectors:
        result = subprocess.run(
            ["cargo", "run", "--quiet", "--release", "-p", "skey-cli", "--", "type", METHODS[vector["inputMethod"]], "0"],
            input=vector["keys"] + "\n",
            text=True,
            capture_output=True,
            cwd=ROOT / "core",
            check=True,
        ).stdout.strip()
        if result != vector["expected"]:
            raise AssertionError(f"{vector['name']}: expected {vector['expected']!r}, got {result!r}")
    print(f"typing vectors OK: {len(vectors)}")


if __name__ == "__main__":
    main()
