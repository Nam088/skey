---
kind: business_term
name: Business Glossary
category: business_term
scope:
    - '**'
---

### SKey
- Definition：A modern Vietnamese input method engine and native macOS menu bar application that combines a zero-heap Rust core typing engine with Swift-based keystroke interception via EventTap, supporting Telex, Simple Telex, VNI, and VIQR schemes.
- Aliases：skey

### Spotlight Search
- Definition：macOS's built-in Spotlight search UI (`NSSearchField`) which SKey must handle specially — using direct Accessibility text replacement rather than synthesized key events — to avoid character duplication caused by Spotlight's debounce timer and window server event coalescing.
- Aliases：Spotlight、NSSearchField

### Omnibox
- Definition：The URL/search bar in Chromium-based browsers (Yandex Browser, Chrome, Edge, Brave) where SKey compensates for inline autocomplete selection by injecting an extra Backspace before typed characters, since the first Backspace is consumed by the browser's selection highlight rather than deleting the actual character.
- Aliases：Chromium Omnibox、address bar

### Cross-App Buffer Leakage
- Definition：A bug pattern where unfinished keystroke buffer state from one application leaks into the next after switching apps or closing Spotlight, causing the first character of the new context to be corrupted; mitigated by resetting the engine on mouse down, hotkey, navigation keys, and app focus change notifications.
- Aliases：buffer leakage、cross-app isolation

### Telex / Simple Telex / VNI / VIQR
- Definition：Vietnamese typing schemes supported by SKey's core engine: Telex (e.g., `dd` → `đ`, `ww` → `ư`), Simple Telex, VNI, and VIQR encoding rules used to convert Latin keystrokes into accented Vietnamese characters.
- Aliases：typing schemes、Vietnamese IME schemes

### Accessibility API
- Definition：macOS AX framework used by SKey to read/write text in third-party applications (Spotlight, browsers, IDEs) without being an IME; includes reading selected text ranges, replacing text directly, and waking dormant Chromium accessibility trees via `AXEnhancedUserInterface = true`.
- Aliases：AX API、kAXSelectedTextAttribute

### EventTap
- Definition：macOS low-level input hook (`CGEventTap`) used by SKey to intercept all keystrokes globally on a dedicated interactive thread, enabling sub-microsecond processing latency without relying on higher-level input methods.
- Aliases：CGEventTap、input hook

### libskey.a
- Definition：The static library produced by the Rust `skey-core` crate through `skey-capi`, linked into the Swift SKey app binary; it contains the no_std, zero-heap Vietnamese typing engine compiled with LTO and single codegen unit for maximum performance.
- Aliases：libskey、skey-core static lib
