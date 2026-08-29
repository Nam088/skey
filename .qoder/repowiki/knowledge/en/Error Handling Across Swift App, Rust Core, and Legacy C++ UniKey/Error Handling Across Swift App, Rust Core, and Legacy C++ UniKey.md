---
kind: error_handling
name: Error Handling Across Swift App, Rust Core, and Legacy C++ UniKey
category: error_handling
scope:
    - '**'
source_files:
    - macos/skey-app/Sources/Features/Translator/Services/TranslationService.swift
    - macos/skey-app/Sources/Features/Clipboard/Services/SQLiteClipboardRepository.swift
    - macos/skey-app/Sources/Shared/Logging/SKeyLogger.swift
    - port/skey-core/src/engine/mod.rs
    - port/skey-capi/src/lib.rs
    - port/difftest/src/main.rs
    - src/vnconv/error.cpp
---

## Overview

This repository contains three distinct codebases sharing one concern — error handling — each following its own language-native conventions rather than a unified scheme.

### macOS Swift App (SKey Super App)

The Swift layer uses **Swift `throws` / `async throws`** with standard Foundation errors as the primary mechanism:

- **Network I/O**: `TranslationService.swift` throws `URLError` variants (`badURL`, `badServerResponse`, `cannotDecodeContentData`, `cannotParseResponse`) for every HTTP call. The service implements a **cascading fallback strategy**: it tries engines in priority order, catches each error, stores the last one, and re-throws only after all configured engines fail plus a final Google NMT safety-net attempt.
- **SQLite persistence**: `SQLiteClipboardRepository.swift` wraps raw `sqlite3_*` calls in `withCheckedThrowingContinuation` and converts SQLite failures into `NSError(domain: "SQLiteClipboardRepository", code: <1..4>, userInfo: [NSLocalizedDescriptionKey: errmsg])`. Each failure point gets a distinct numeric code (open, insert step, prepare, fetch).
- **Fatal paths**: `fatalError("init(coder:) has not been implemented")` is used in IB-decoded view controllers that are never instantiated from storyboards, signaling programming errors rather than runtime recoverable failures.
- **Logging as side-effect of errors**: `SKeyLogger.swift` provides a centralized `os.Logger` sink. Errors are logged at `.error` level; debug logs are gated behind `#if DEBUG` and an `AppSettings.shared.general.isDebugMode` flag. Log files are written asynchronously on a low-priority queue to avoid blocking event taps, with 2 MB rotation and `0600` POSIX permissions enforced.
- **Catch sites**: UI layers use bare `} catch { }` blocks (e.g. `ToolsSettingsTab.swift`, `TranslationHUDView.swift`) swallowing errors silently, while services propagate them upward via `throws`.

### Rust Core (`port/skey-core`)

The core engine is built under strict constraints documented in comments:

- `#![forbid(unsafe_code)]` and `#![cfg_attr(not(test), no_std)]` — the keystroke path allocates nothing and panics are avoided by design. The engine returns structured `Edit` values (`engine/mod.rs`) carrying `backspaces`, `out_type`, and `handled` flags instead of using exceptions or error codes.
- No `Result<T, E>` return types appear in the hot path; failures are modeled as state transitions within the `Engine` struct and surfaced through the `Edit` result. This keeps the input pipeline zero-allocation and panic-free.
- Test harnesses under `port/difftest/` use `unwrap()` and `expect("corpus")` liberally because they are test-only tools, not production code.

### Rust FFI Bridge (`port/skey-capi`)

The C ABI wrapper is the single place where `unsafe` lives, justified by comments: "the original's threading model" and "FFI boundary have to be real symbols". Error handling here is **C-style**: functions return sentinel values (`0` for failure, `1` for success) or write results into caller-supplied buffers. For example, `UnikeyLoadMacroTable` returns `0` when the file cannot be read, and `UnikeySetInputMethod` ignores invalid input method values silently. A `handle!` macro short-circuits null pointer dereferences by returning early or returning a `NO_EDIT` sentinel.

### Legacy C++ UniKey (`src/`)

The legacy C/C++ components follow classic C error patterns:

- `vnconv/error.cpp` defines a commented-out `ErrTable[]` of string messages indexed by `VNCONV_LAST_ERROR` and a `VnConvErrMsg(int)` accessor — an error-code-to-message mapping that was moved out due to export issues (noted in a TODO comment).
- Other modules (`ukengine`, `xim`, `gui`) do not define custom error types; errors are propagated via integer return codes and global state, consistent with C conventions.

## Conventions Observed

| Layer | Pattern | Enforcement Source |
|---|---|---|
| Swift app | `throws` + `async throws` with `URLError` / `NSError`; cascading fallback with last-error capture | Code pattern in `TranslationService.translate` |
| SQLite repo | `NSError(domain: "SQLiteClipboardRepository", code: N)` per failure site | `SQLiteClipboardRepository.swift` |
| Swift logging | Centralized `SKeyLogger` via `os.Logger`; debug logs disabled outside DEBUG builds | `SKeyLogger.log` with `#if !DEBUG` guard |
| Rust core | Structured `Edit` return value; no `Result`, no panics in hot path | `engine/mod.rs` + `#![forbid(unsafe_code)]` |
| Rust FFI | Sentinel return values (`0`/`1`) and optional handles via `handle!` macro | `skey-capi/src/lib.rs` |
| Legacy C++ | Integer return codes; commented-out error message table | `vnconv/error.cpp` |

## Key Files

- `macos/skey-app/Sources/Features/Translator/Services/TranslationService.swift` — cascading translation with `URLError` propagation
- `macos/skey-app/Sources/Features/Clipboard/Services/SQLiteClipboardRepository.swift` — SQLite error mapping to `NSError`
- `macos/skey-app/Sources/Shared/Logging/SKeyLogger.swift` — unified error logging with build-gated debug output
- `port/skey-core/src/engine/mod.rs` — `Edit`-based non-throwing error model for the keystroke path
- `port/skey-capi/src/lib.rs` — C ABI sentinel-value error handling and null-pointer guards
- `port/difftest/src/main.rs` — test harness using `unwrap()`/`expect()` (test-only scope)
- `src/vnconv/error.cpp` — legacy error message table (commented out, moved to convert.cpp)