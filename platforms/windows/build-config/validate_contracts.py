#!/usr/bin/env python3
"""Validate shared Windows contracts without third-party dependencies."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def load(name):
    with (ROOT / "shared" / "contracts" / name).open(encoding="utf-8") as stream:
        return json.load(stream)


def main():
    config = load("config.schema.json")
    ipc = load("ipc.schema.json")
    keys = load("localization.keys.json")["keys"]
    with (ROOT / "shared" / "typing-vectors" / "basic.json").open(encoding="utf-8") as stream:
        vectors = json.load(stream)["vectors"]
    parity = load("feature-parity.json")

    assert config["properties"]["theme"]["enum"] == ["system", "light", "dark"]
    assert ipc["properties"]["protocolVersion"]["const"] == 1
    assert len(keys) == len(set(keys)) and all(keys)
    assert vectors and all(v["inputMethod"] in {"telex", "vni", "viqr", "simpleTelex"} for v in vectors)
    assert all(v["keys"] and v["expected"] for v in vectors)
    assert set(parity["macosFeatureGroups"]) == {"Cleaner", "Clipboard", "Keyboard", "Settings", "Translator"}
    assert set(parity["sharedGroups"]) == {"Core", "Localization", "Logging", "Services", "Settings", "Shortcuts", "UI"}
    print(f"contracts OK: {len(keys)} localization keys, {len(vectors)} typing vectors, UI parity OK")


if __name__ == "__main__":
    main()
