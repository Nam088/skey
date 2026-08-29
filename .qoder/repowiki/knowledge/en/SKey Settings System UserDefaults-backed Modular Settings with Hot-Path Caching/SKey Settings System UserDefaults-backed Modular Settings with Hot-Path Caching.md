---
kind: configuration_system
name: 'SKey Settings System: UserDefaults-backed Modular Settings with Hot-Path Caching'
category: configuration_system
scope:
    - '**'
source_files:
    - macos/skey-app/Sources/Shared/Settings/AppSettings.swift
    - macos/skey-app/Sources/Shared/Settings/SettingsStorage.swift
    - macos/skey-app/Sources/Shared/Settings/SettingsModule.swift
    - macos/skey-app/Sources/Shared/Settings/Modules/GeneralSettings.swift
    - macos/skey-app/Sources/Shared/Settings/Modules/KeyboardSettings.swift
    - macos/skey-app/Sources/Shared/Settings/Backup/SettingsBackupManager.swift
    - src/xim/ukopt.c
    - src/gui/gui.c
    - src/unikey-gtk/gtkimcontextvn.c
---

## Overview

The repository contains two distinct configuration systems that serve different layers of the application:

1. **macOS SKey App (Swift)** — A modern, modular settings system built on `UserDefaults` with an in-memory cache, Combine reactivity, and per-module default registration.
2. **Legacy UniKey C/C++ XIM/GTK components** — A traditional key=value config-file parser for Unix/Linux deployments.

There is no shared configuration format between the two; they are independent subsystems.

---

## macOS SKey App Settings System

### Architecture

The Swift app centralizes all user preferences through a single global hub:

- **`AppSettings`** (`Sources/Shared/Settings/AppSettings.swift`) — singleton exposing typed sub-modules: `keyboard`, `clipboard`, `macro`, `general`, `shortcuts`, `translator`. It owns the `SettingsStorage` instance and provides `resetAll()` to restore factory defaults across every module.
- **`SettingsModule` protocol** (`SettingsModule.swift`) — defines the contract each feature module must implement: a static `prefix` string for namespacing keys, `registerDefaults(in:)` to seed defaults, and `resetToDefaults()` to wipe persisted values back to factory state.
- **`SettingsStorage`** (`SettingsStorage.swift`) — thread-safe wrapper around `UserDefaults` with a lock-protected in-memory `[String: Any]` cache. Reads hit RAM first (0ns hot path); writes update RAM immediately and flush to disk asynchronously on a background `DispatchQueue` labeled `com.nam088.skey.settings.io`.
- **Per-module classes** under `Sources/Shared/Settings/Modules/`: `GeneralSettings`, `KeyboardSettings`, `ClipboardSettings`, `MacroSettings`, `ShortcutSettings`, `TranslatorSettings`. Each declares its own `Keys` enum of fully-qualified `UserDefaults` keys (e.g. `SKey_IsVietnamese`, `SKey_AppLanguage`) and exposes typed Swift properties backed by `storage.bool/string/integer/data(...)`.

### Persistence & Defaults

- Defaults are registered via `storage.registerDefaults([:])` during each module's init. If a key has no persisted value, `registerDefaults` seeds both `UserDefaults` and the in-memory cache.
- Values are persisted to `UserDefaults.standard` asynchronously after write, so the typing pipeline never blocks on disk I/O.
- Complex data (e.g. `excludedApps: [ExcludedApp]`) is JSON-encoded into `Data` before storage.

### Reactive UI Integration

Each module inherits from `NSObject` and conforms to `ObservableObject` (Combine). Property setters call `objectWillChange.send()` so SwiftUI views observing the module react instantly. The `AppSettings.shared` singleton is consumed throughout the app — features read settings directly (e.g. `AppSettings.shared.keyboard.inputMethod`, `AppSettings.shared.macro.isEnabled`).

### Backup / Export / Import

`SettingsBackupManager` (`Sources/Shared/Settings/Backup/SettingsBackupManager.swift`) serializes the entire `AppSettings` snapshot into a `Codable` `SKeyBackupData` structure and supports:
- `createBackupSnapshot()` — reads current values from all modules.
- `exportSettings(completion:)` — prompts `NSSavePanel`, writes pretty-printed JSON with ISO-8601 dates.
- `importSettings(completion:)` — prompts `NSOpenPanel`, decodes JSON, then calls `applyBackup(_)` which writes values back into every module and also syncs low-level engine state via `EventTapManager.shared.engine.set*` calls and `LocalizationService.shared.currentLanguage`.

### Conventions Observed

- Every setting key is a `static let` inside a module-scoped `Keys` enum, prefixed with `SKey_<Feature>_` (e.g. `SKey_Keyboard_...`, `SKey_General_...`).
- Modules declare a `static var prefix: String` matching their key namespace (used by backup/export logic).
- Feature flags gated behind `#if DEBUG` build configurations (e.g. `isDebugMode` returns `false` in Release builds regardless of stored value).
- Hot-path settings (e.g. `isAppExcluded(bundleID:)`) maintain a secondary in-memory `Set<String>` cache protected by `os_unfair_lock` for O(1) lookups in the typing pipeline.
- Changes propagate bidirectionally: writing a setting updates the in-memory cache, persists async, and triggers `objectWillChange` so UI and engine listeners stay in sync.

---

## Legacy UniKey C/C++ Configuration

The legacy Unix/XIM/GTK components use a flat text config file parsed by a hand-rolled option parser.

### Config File Format

- File location: configurable via `-config <file>` CLI flag or resolved by `UkGetDefConfFileName()`; default path referenced as `~/.unikey/option` in help text.
- Key-value pairs with `=` separator, e.g. `Input = TELEX`, `Charset = UNICODE`, `AutoSave = Yes`.
- Lines beginning with `#` are comments; the parser includes inline documentation strings describing each option (e.g. `InitStateCmt`, `InputCmt`, `CharsetCmt`, `FreeStyleCmt`, `ModernStyleCmt`, `CommitMethodCmt`, `XimFlowCmt`, `XimLocalesCmt`, `UsrKeyMapFileCmt`, `EnableSpellCheckCmt`, `AutoRestoreNonVnCmt`).

### Parser & Option Registry

- `ukopt.c` defines `UkXimOptList`, an array of `OptItem` entries mapping option names to struct offsets, types (`BoolOpt`, `StrOpt`, `LongOpt`, `LookupOpt`), and human-readable comment strings.
- Lookup tables (`InputLookup`, `CharsetLookup`, `StateLookup`, `CommitLookup`, `XimFlowLookup`) map string tokens to numeric enums.
- `ParseOptFile(fileName, options, UkXimOptList, ...)` in `optparse.c` performs the actual parsing.
- `UkParseOptFile` additionally expands `~` in paths like `MacroFile` and `UsrKeyMapFile` via `ParseExpandFileName`.

### Runtime Behavior

- GUI (`src/gui/gui.c`) accepts `-config <file>` and passes it to `UkGuiParseOptFile`, which delegates to the same parser.
- GTK IM context (`src/unikey-gtk/gtkimcontextvn.c`) resolves the default config filename at startup, calls `reloadConfig()`, and can reload on demand.
- `AutoSave` option controls whether the process writes the config file back on exit (with a warning about concurrent edits).

---

## Cross-Cutting Notes

- The Swift settings system and the legacy C config files are **not interoperable**. They target different platforms (macOS app vs. Unix/XIM) and use completely different formats.
- There is no environment-variable-based configuration layer in either subsystem; all configuration is file/`UserDefaults` based.
- No centralized schema validation exists beyond the type-safe Swift property accessors and the C lookup-table-driven parser.