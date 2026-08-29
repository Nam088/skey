---
kind: logging_system
name: SKey macOS Unified Logging with os.log, In-Memory Store, and File Sink
category: logging_system
scope:
    - '**'
source_files:
    - macos/skey-app/Sources/Shared/Logging/SKeyLogger.swift
    - macos/skey-app/Sources/Shared/Logging/LogEntry.swift
    - macos/skey-app/Sources/Shared/Logging/LogStore.swift
---

## What system/approach is used

The SKey macOS application implements a custom logging layer built on top of Apple's **Unified Logging** (`os.Logger`) via the `os.log` framework. The logger provides three concurrent sinks:
1. **Apple Console / Unified Log** — all levels are forwarded to `os.Logger(subsystem: "com.nam088.skey", category: "General")`, which is zero-allocation when inactive.
2. **In-memory ring buffer** (`LogStore`) — thread-safe, capacity-limited (default 500 entries) store that broadcasts new entries via `NotificationCenter` (`skeyDidEmitLog`) and direct callbacks for real-time UI streaming.
3. **Asynchronous file sink** — writes formatted lines to `/tmp/skey.log` on a dedicated low-priority `DispatchQueue` (`qos: .utility`).

The legacy C/C++ UniKey engine under `src/` does **not** use a unified logging framework; it uses ad-hoc `printf`/`fprintf(stderr, ...)` calls scattered in sample code and data files, which are not part of the active runtime logging strategy.

## Key files and packages

- `macos/skey-app/Sources/Shared/Logging/SKeyLogger.swift` — singleton logger facade exposing `SKeyLogger.shared` and global convenience functions `SKeyLog.debug/info/warning/error` plus a backwards-compatible `skeyLog(...)` function.
- `macos/skey-app/Sources/Shared/Logging/LogEntry.swift` — defines `LogLevel` (`debug`, `info`, `warning`, `error`), `LogCategory` (`App`, `Keyboard`, `Clipboard`, `Permissions`, `Engine`, `UI`, `General`), and the `LogEntry` value type carrying `id`, `timestamp`, `level`, `category`, `message`, `file`, `line`.
- `macos/skey-app/Sources/Shared/Logging/LogStore.swift` — thread-safe in-memory log store with append, query by level/category, clear, subscribe/unsubscribe, and `NotificationCenter` broadcast on main queue.

## Architecture and conventions

### Single entry point
All logging goes through `SKeyLogger.shared.log(level:category:message:file:line:)`. Callers should use the convenience wrappers `SKeyLog.debug/info/warning/error(...)` or the legacy `skeyLog(...)` helper; direct instantiation of `SKeyLogger` is discouraged since the class has a private initializer.

### Structured fields
Each log entry carries structured metadata: `LogLevel`, `LogCategory`, source `file` (last path component only), and `line`. Entries are `Codable` and `Identifiable`, enabling serialization and SwiftUI observation.

### Three-tier sink pipeline
For every call the logger performs three operations in order:
1. Emit to `os.Logger` at the matching level.
2. Append to the in-memory `LogStore` (always in DEBUG builds; in release builds only `warning` and `error` are buffered).
3. If running in a DEBUG build **and** `AppSettings.shared.general.isDebugMode` is true, enqueue a formatted line to the background file writer.

### Security and performance constraints
- Debug-level logs are **strictly disabled** in non-DEBUG builds (`#if !DEBUG` early return). In DEBUG builds they are gated by `isDebugMode` so they can be toggled at runtime.
- File I/O runs off the main/event-tap path on a `.utility` QoS queue named `com.nam088.skey.logger.file` to avoid blocking realtime input processing.
- The log file (`/tmp/skey.log`) is created with POSIX permissions `0600` (owner read/write only) and rotated (deleted) once it exceeds 2 MB.
- Messages passed to `os.Logger` are tagged with `privacy: .public`; categories are embedded as a `[Category]` prefix in the message string rather than as an `os.Logger` category parameter.

### UI integration
`LogStore` posts `Notification.Name.skeyDidEmitLog` on the main queue whenever a new entry is appended, and also invokes registered observer closures. A `skeyLogStoreDidClear` notification is posted after clearing. Consumers subscribe via `LogStore.shared.subscribe { ... }` and receive a token used to unsubscribe later.

### Categories
`LogCategory` enumerates the logical subsystems: `App`, `Keyboard`, `Clipboard`, `Permissions`, `Engine`, `UI`, `General`. All callers must supply one; the default is `.general`.

## Conventions and constraints

- **Use the public API**: call `SKeyLog.debug/info/warning/error(message, category: ..., file: #file, line: #line)` from application code. Do not instantiate `SKeyLogger` directly.
- **Always provide a `LogCategory`** that matches the feature area emitting the log.
- **Never log secrets or PII** — messages are written to both the OS console and potentially to `/tmp/skey.log` with `0600` permissions.
- **Debug logs are development-only**: they compile out in release builds and are additionally gated behind `isDebugMode` in debug builds.
- **File logging is opt-in even in debug builds**: requires `AppSettings.shared.general.isDebugMode == true`; otherwise only `os.Logger` and the in-memory buffer are used.
- **In-memory buffer is bounded**: oldest entries are dropped when the 500-entry capacity is exceeded; consumers should consume entries promptly.
- **Legacy C/C++ code** under `src/` does not participate in this system — it uses raw `printf`/`fprintf` and is unrelated to the SKey app's logging.