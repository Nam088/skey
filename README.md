# SKey — Modern Vietnamese Input Method Engine & macOS App

SKey is an ultra-fast, modern Vietnamese input method engine and native macOS application. It pairs a **100% safe Rust core typing engine** with a **native Swift macOS menu bar app** built for zero-latency keystroke processing.

---

## ✨ Features

- **Blazing Fast**: Sub-microsecond keystroke latency powered by a `no_std`, zero-heap Rust engine (`skey-core`).
- **Native macOS App**: Light footprint menu bar application with low-overhead CoreGraphics EventTap running on a dedicated interactive thread.
- **Spotlight & Omnibox Compatibility**: Deep Accessibility API integration seamlessly handles Spotlight search, floating palettes, and Chromium/Safari URL autocomplete without caret conflicts.
- **Smart App Switching**: Automatically switches to English mode in developer applications (Terminal, iTerm2, Warp, VS Code, Xcode, JetBrains IDEs) and restores Vietnamese elsewhere.
- **Rich Typing Schemes**: Complete support for **Telex**, **Simple Telex**, **VNI**, and **VIQR**.
- **Modern Vietnamese Options**: Modern tone placement (`oà`, `uý`), free tone marking, spell checking, and English swallowed key recovery.
- **Built-in Clipboard Manager**: Lightweight, thread-safe system clipboard history accessible from the menu bar.
- **Terminal CLI REPL**: Interactive command-line typing REPL (`skey-cli`) for terminal environments and automated testing.

---

## 🏗 Project Structure

```
├── macos/
│   └── skey-app/        # Native macOS Menu Bar application (Swift)
├── port/
│   ├── skey-core/       # Core Vietnamese typing engine (Rust, no_std, safe)
│   ├── skey-capi/       # C ABI bindings and static library (libskey.a)
│   ├── skey-cli/        # Interactive terminal REPL
│   └── difftest/        # Differential testing against reference engine
└── src/                 # Original reference C++ engine sources
```

---

## 🚀 Quick Start

### Build & Run SKey macOS App

Prerequisites:
- macOS 13+
- Xcode Command Line Tools (`swiftc`, `codesign`)
- Rust toolchain (`cargo`)

```bash
cd macos/skey-app
./build.sh
```

The script compiles `libskey.a`, builds `SKey.app` with Whole Module Optimization (`-wmo`), signs it with the local certificate, and installs it into `/Applications/SKey.app`.

### Build & Test Rust Core Engine

```bash
cd port
cargo build --release --workspace
cargo test --release -p skey-core
```

### Run Terminal REPL

```bash
cargo run --release -p skey-cli
```

---

## 📜 License

This project is licensed under the **GNU General Public License v2.0 (GPL-2.0)**.
