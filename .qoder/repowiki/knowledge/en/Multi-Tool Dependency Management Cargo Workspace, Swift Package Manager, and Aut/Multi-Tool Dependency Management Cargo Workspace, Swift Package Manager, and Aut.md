---
kind: dependency_management
name: 'Multi-Tool Dependency Management: Cargo Workspace, Swift Package Manager, and Autotools'
category: dependency_management
scope:
    - '**'
source_files:
    - port/Cargo.toml
    - port/Cargo.lock
    - port/skey-core/Cargo.toml
    - port/skey-capi/Cargo.toml
    - port/skey-cli/Cargo.toml
    - macos/skey-app/Package.swift
    - Casks/skey.rb
    - src/Makefile.am
---

## Overview

This repository manages dependencies across three distinct build ecosystems that coexist in a single monorepo:

1. **Rust workspace** (`port/`) — the primary modern codebase using Cargo.
2. **macOS app** (`macos/skey-app/`) — a native Swift AppKit/SwiftUI application using Swift Package Manager (SPM) plus direct linking to a prebuilt Rust cdylib.
3. **Legacy C/C++ UniKey suite** (`src/`) — an autotools-based tree of C/C++ components with no external package manager.

There is no unified dependency manifest at the repository root; each subsystem declares its own dependencies independently.

## Rust workspace (`port/`)

- **Workspace definition**: `port/Cargo.toml` defines a Cargo workspace with resolver v2 and four members: `skey-core`, `skey-capi`, `skey-cli`, `difftest`. A shared `[profile.release]` enables LTO and single codegen unit for all crates.
- **Lockfile**: `port/Cargo.lock` pins every transitive crate from `crates.io` by name, version, source URL, and SHA-256 checksum. It is committed to the repo, so builds are deterministic without network access beyond the registry index.
- **Dependency declarations**:
  - `skey-core` depends only on optional `serde` (feature-gated via `features = ["serde"]`) and `serde_json` as a dev-dependency used only by a cfg-gated round-trip test. The crate's default features are `testkit` and `alloc`, keeping the core minimal and alloc-only.
  - `skey-capi` re-exports `skey-core` with `default-features = false` and only the `alloc` feature enabled, producing a `cdylib` + `staticlib` + `rlib` triple output named `skey`.
  - `skey-cli` and `difftest` depend on `skey-core` through path dependencies (`path = "../skey-core"`).
- **No private registries or vendoring**: All third-party crates come from `registry+https://github.com/rust-lang/crates.io-index`; there is no `.cargo/config.toml`, no `source.crates-io.replace-with`, and no `vendor/` directory.
- **Versioning style**: Crates use caret-style ranges (`"1"`, `"1.0"`) rather than exact pinning in `Cargo.toml`; pinned versions live exclusively in `Cargo.lock`.

## macOS app (`macos/skey-app/`)

- **SPM manifest**: `Package.swift` (swift-tools-version 5.9) defines one executable target `SKey` depending on a local C target `CSKey` (a thin wrapper around the Rust cdylib). Platform constraint is `macOS(.v26)`.
- **External library linkage**: The app does not declare SPM packages for its system dependencies. Instead it uses linker settings to link against system frameworks (`Cocoa`, `ApplicationServices`, `Carbon`, `SwiftUI`, `CryptoKit`) and the system `sqlite3` library, plus a prebuilt Rust library located at `../../port/target/release` via `-L` and `-lskey`. This means the Rust workspace must be built first before the Swift app can link.
- **No SPM package manifests for third-party Swift libraries**: The app appears to rely entirely on Apple frameworks and the locally built `skey` cdylib; no external Swift packages are declared.

## Legacy C/C++ suite (`src/`)

- **Autotools build**: The `src/` tree uses `Makefile.am` / `Makefile.in` files organized into subdirectories (`byteio`, `vnconv`, `ukengine`, `ukinterface`, `IMdkit`, `xim`, `gui`, `unikey-gtk`). The top-level `Makefile.am` lists these as `SUBDIRS` and conditionally includes `unikey-gtk` based on `COND_UNIKEY_GTK`.
- **No package manager**: There is no `configure.ac` visible in the snapshot, no `go.mod`, no `package.json`, and no vendored sources under `src/`. Dependencies appear to be assumed to be provided by the host system (e.g., X11/XIM, GTK, ICU/charset libraries), which is typical for legacy Unix input method suites.
- **Build-time tooling**: Differential tests under `port/difftest/` invoke Python scripts (`ctxsweep.py`, `keymapsweep.py`, `macrosweep.py`, `soak.py`, `quick.sweep`, `sweep.py`) and a small Rust harness (`port/difftest/src/main.rs`, `port/oracle/oracle_rust/...`) to compare outputs between the Rust port and the original C++ engine.

## Distribution and update channels

- **Homebrew Cask**: `Casks/skey.rb` distributes the prebuilt `SKey.app` bundle via Homebrew. It pins a release version (`1.0.13`) and downloads the installer DMG from GitHub Releases. The cask declares a macOS minimum version (`>= :sonoma`) but no additional formula dependencies.
- **CI-driven builds**: `.github/workflows/ci.yml` drives dependency resolution through `cargo build --release --workspace` and `make oracle rust ... tables sweep capi-check ctx-check`, confirming that both Cargo and autotools invocations are part of the canonical build pipeline.

## Conventions and constraints observed

- **Deterministic Rust builds**: `Cargo.lock` is committed and regenerated by Cargo; updates should go through `cargo update` followed by committing the new lockfile.
- **Feature-minimal core**: `skey-core` disables default features when consumed by `skey-capi` (`default-features = false, features = ["alloc"]`), enforcing a lean ABI surface.
- **Local path dependencies within the workspace**: All intra-workspace Rust crates reference each other via `path = "../skey-core"` rather than publishing to crates.io, keeping the workspace self-contained.
- **Cross-language boundary via cdylib**: The Swift app consumes the Rust engine through a compiled `lib skey.dylib` produced by `skey-capi`; this is linked explicitly via SPM linker flags rather than through SPM package resolution.
- **Legacy C/C++ has no centralized dependency declaration**: External libraries are expected to be present on the build machine; there is no mechanism in `src/` to fetch or vendor them.