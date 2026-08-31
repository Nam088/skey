---
kind: build_system
name: Multi-Project Build & Release Pipeline (Rust Workspace + Swift App + Legacy C++ Autotools)
category: build_system
scope:
    - '**'
source_files:
    - port/Makefile
    - port/Cargo.toml
    - macos/skey-app/build.sh
    - macos/skey-app/Package.swift
    - scripts/build_release.sh
    - scripts/create_dmg.sh
    - .github/workflows/ci.yml
    - .github/workflows/build-and-release-macos.yml
    - .github/workflows/update-cask.yml
    - Casks/skey.rb
---

## What system/approach is used

The repository builds three distinct subsystems with separate toolchains and release flows:

1. **Rust workspace** (`port/`) — the modern SKey engine, a C ABI binding crate (`skey-capi`), a CLI (`skey-cli`), and differential testing harnesses against the original C++ UniKey engine. Built via `cargo build --release --workspace` with LTO and single codegen unit enabled in `[profile.release]`.
2. **macOS native app** (`macos/skey-app/`) — a Swift/SwiftUI application that links the prebuilt `libskey.a` from the Rust workspace through an Objective-C bridging header (`Support/BridgingHeader.h`). Compiled directly with `swiftc -O -wmo`, not via Xcode project files.
3. **Legacy C/C++ UniKey suite** (`src/`) — autotools-based build tree (`Makefile.am` / `Makefile.in`) for the original input method engine, XIM/GTK bridges, charset conversion, and X11 GUI.

CI is GitHub Actions: `ci.yml` runs on every push/Pull Request plus a nightly scheduled job; `build-and-release-macos.yml` builds universal macOS binaries and publishes releases; `update-cask.yml` bumps the Homebrew cask after a successful release.

## Key files and packages

- `port/Makefile` — orchestrates building the C++ oracle, the Rust library, both C ABI harnesses (`oracle_rust`, `ctx_harness`), table regeneration from the C++ binary, exhaustive/random differential sweeps (`sweep`, `soak`, `macrosweep`, `keymapsweep`, `quicksweep`, `capi-check`, `ctx-check`), portability matrix (`--no-default-features`, wasm32, serde feature), benchmarks, and golden hash re-freezing.
- `port/Cargo.toml` — workspace definition declaring members `skey-core`, `skey-capi`, `skey-cli`, `difftest`; global release profile with `lto = true` and `codegen-units = 1`.
- `port/skey-core/Cargo.toml` and `port/skey-capi/Cargo.toml` — core engine and C ABI crate manifests.
- `macos/skey-app/build.sh` — local development build script: builds `libskey.a`, assembles `SKey.app` bundle structure, stamps version from `git describe --tags`, copies localization resources, compiles all Swift sources with `swiftc -O -wmo`, codesigns with certificate `SKeyDev`, and installs to `/Applications/SKey.app`.
- `scripts/build_release.sh` — release pipeline: adds `aarch64-apple-darwin` and `x86_64-apple-darwin` targets via `rustup`, builds both architectures, creates a universal `libskey.a` with `lipo -create`, generates app icon via `scripts/generate_app_icon.swift`, compiles two Swift binaries targeting `arm64-apple-macos26.0` and `x86_64-apple-macos26.0`, merges them into a universal `SKey.app/Contents/MacOS/SKey`, ad-hoc signs, calls `scripts/create_dmg.sh`, zips the app, and writes `SHA256SUMS.txt`.
- `scripts/create_dmg.sh` — stages `SKey.app` plus an `Applications` symlink into a writable HFS+ disk image, configures Finder presentation with a generated background PNG, converts to compressed UDZO DMG named `SKey-Installer.dmg`.
- `macos/skey-app/Package.swift` — Swift Package manifest declaring minimum platform macOS v26, linking `CSKey` module, the `../../port/target/release/libskey` static lib, frameworks Cocoa/ApplicationServices/Carbon/SwiftUI/CryptoKit, and `sqlite3`.
- `.github/workflows/ci.yml` — enforces `RUSTFLAGS = -D warnings`, caches cargo registry/git/port/target keyed on `Cargo.lock`, runs `cargo test --release`, verifies no-allocator build, wasm32 target, serde feature, then builds oracle/oracle-rust/ctx-harness and runs full differential sweep matrix.
- `.github/workflows/build-and-release-macos.yml` — triggers on pushes to main/master and `v*` tags, auto-bumps semantic version based on commit messages since last tag, selects Xcode 26, builds universal artifacts, uploads `SKey-Installer.dmg`, `SKey-macOS-Universal.zip`, `SHA256SUMS.txt`, generates release notes, and publishes a GitHub Release.
- `.github/workflows/update-cask.yml` — runs after a successful macOS release, downloads the DMG asset, computes SHA256, updates `Casks/skey.rb` with version/arch blocks, commits and pushes back.
- `src/Makefile.am` / `src/Makefile.in` — legacy autotools definitions for the C++ UniKey components (ukengine, vnconv, byteio, gui, xim, unikey-gtk, IMdkit).

## Architecture and conventions

- **Single source of truth for the engine**: the Rust `skey-core` crate is the canonical implementation; the C++ `src/` tree exists only as the reference oracle for differential testing and legacy compatibility. The Makefile explicitly documents this relationship (`make oracle` builds the C++ reference, `make tables` regenerates Rust tables from the C++ binary).
- **Differential testing gates correctness**: every CI run compares the Rust engine against the compiled C++ oracle across exhaustive, random, macro, keymap, and context-sweep corpora. Golden hashes live in `skey-core/tests/golden_hashes.in` and are re-frozen only via `make golden` with a review step.
- **Dual C ABI surface**: `skey-capi` exposes a standard C ABI (`target/release/libskey.a`) consumed by the Swift app via `swiftc -lskey`, while `oracle/oracle_rust` and `oracle/ctx_harness` drive the same Rust code through the C ABI to validate end-to-end behavior.
- **Universal macOS distribution**: release builds compile both `aarch64` and `x86_64` variants of both the Rust static lib and the Swift executable, then merge with `lipo -create`. The resulting `SKey.app` contains a universal Mach-O binary.
- **Versioning strategy**: versions come from git tags (`git describe --tags --abbrev=0`); the release workflow auto-bumps major/minor/patch based on conventional commit keywords (`BREAKING CHANGE|major:` → major bump, `feat|minor:` → minor, else patch) and pushes the new tag before building.
- **App bundle assembly**: the Swift app is not built through an Xcode project; `build_release.sh` and `build.sh` manually assemble `SKey.app/Contents/{MacOS,Resources}` and stamp `CFBundleShortVersionString` / `CFBundleVersion` via `PlistBuddy`.
- **DMG packaging**: installer images use a writable HFS+ intermediate, a generated background PNG, and `hdiutil convert` to UDZO with zlib level 9.
- **Homebrew integration**: `Casks/skey.rb` is updated automatically by CI after each successful release, pulling the DMG URL and SHA256 from the published GitHub Release.

## Conventions and constraints

- Warnings are treated as errors in CI (`RUSTFLAGS: -D warnings`), enforced by the GitHub Actions environment variable in `.github/workflows/ci.yml`.
- The Rust workspace uses resolver `2` and a single shared release profile with LTO and one codegen unit for maximum optimization.
- Differential tests require the C++ oracle to be built first; `make verify` chains `sweep`, `soak`, `macrosweep`, `keymapsweep`, `quicksweep`, `capi-check`, `ctx-check`, `portability`, and `test`.
- Portability must hold under three configurations: no default features (no allocator), `wasm32-unknown-unknown` target, and `serde` feature — verified by `make portability` and mirrored in CI.
- Table generation is reproducible: `make tables` rebuilds `tablegen/dump` from the C++ sources, runs it to produce `tablegen/tables.rs`, and copies it into `skey-core/src/phonetics/tables.rs`; CI checks that these files have not changed when tables are regenerated.
- The macOS release workflow requires Xcode 26 (selected via `xcode-select`) to target macOS 26 SDK and render Liquid Glass UI natively.
- Code signing uses either the trusted `SKeyDev` certificate (local dev build) or ad-hoc signing (`codesign --sign -`) during CI release builds.
- Artifacts produced by the release workflow are `dist/SKey-Installer.dmg`, `dist/SKey-macOS-Universal.zip`, and `dist/SHA256SUMS.txt`, uploaded as GitHub Actions artifacts and attached to the GitHub Release.