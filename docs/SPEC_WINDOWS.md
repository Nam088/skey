# Windows IME Technical Specification

## 1. Phạm vi

Đây là đặc tả cho frontend Windows dựa trên behavior của `macos/skey-app` và API của `port/skey-capi`. Phạm vi không bao gồm việc sửa hoặc di chuyển code hiện tại.

## 2. Process model

```text
skey-ime.exe       TSF/IMM32, hot path, không UI/network/storage
skey-tray.exe      tray, lifecycle, shortcut và IPC client
skey-settings.exe  WinUI 3, config/localization/theme
```

`skey-ime.exe` không link WinUI, SQLite, WebView hoặc network client.

## 3. Event contract

```cpp
enum class EventKind : uint8_t {
    KeyDown, KeyUp, FlagsChanged, Backspace, Delete,
    WordBreak, Navigation, FocusChanged, AppChanged, Reset
};

struct KeyEvent {
    EventKind kind;
    uint32_t codepoint;
    uint32_t key_code;
    uint32_t modifiers;
    uint8_t repeat;
};

struct EditResult {
    uint8_t handled;
    uint16_t backspaces;
    uint16_t text_length;
    uint8_t committed;
    uint8_t reset;
};
```

Key event phải được chuyển thành contract này trước khi gọi Rust core. Event không liên quan phải pass-through.

## 4. Composition contract

Trạng thái:

```text
Idle → Composing → Updated → Committed
                    ↘ Cancelled
```

Quy tắc:

- Key biến đổi tạo hoặc cập nhật composition.
- `backspaces` là số ký tự host phải xóa trước khi insert output.
- Word break commit composition rồi reset word state.
- Escape, navigation, modifier shortcut, focus/app change reset composition.
- Host rejection phải hủy hoặc khôi phục composition, không lặp input.
- Selection hiện tại phải được tôn trọng; không tự xóa ngoài vùng composition.

## 5. MacOS behavior mapping

```text
SKeyEngine                  → CoreEngineAdapter
TypingPipeline              → KeyEventPipeline
EventTapManager             → TsfTextService/Imm32Adapter
KeyEventSender              → CompositionHost
AccessibilityContextReader  → TsfContextReader
AppFocusObserver            → ContextTracker
AppSettings                 → SettingsStore
SwiftUI Settings            → WinUI 3 Settings
StatusBarManager            → Win32 Tray
```

Thuật toán tiếng Việt không được lặp lại trong Windows adapter.

## 6. Layer rules

```text
Windows UI/Tray
      ↓
Windows adapter
      ↓
Shared contracts/C ABI
      ↓
Rust core
```

- Core không biết Windows.
- Adapter không biết theme/localization.
- UI không nhận raw keyboard event.
- Storage/IPC không nằm trong key path.
- Mọi IPC message có `protocolVersion`.

## 7. Shared settings

```json
{
  "schemaVersion": 1,
  "locale": "vi-VN",
  "theme": "system",
  "inputMethod": "telex",
  "charset": "unicode",
  "isVietnamese": true,
  "shortcuts": {},
  "macros": [],
  "excludedApps": []
}
```

Locale hợp lệ gồm `vi-VN`, `en-US`; theme gồm `system`, `light`, `dark`. Field không hợp lệ phải fallback và ghi diagnostic.

## 8. IPC contract

Message tối thiểu:

```text
getStatus
setLanguage
setInputMethod
resetEngine
getSettings
setSettings
restartService
```

IPC có timeout, request id, response error code và giới hạn payload.

## 9. Test requirements

- Golden/differential test phải khớp Rust/C++ oracle.
- Fake text host test không cần desktop Windows.
- TSF/IMM32 integration test chạy trên Windows.
- UI ViewModel test độc lập XAML.
- UI automation kiểm tra locale/theme/keyboard navigation.
- E2E kiểm tra Notepad, Chromium, Terminal, app switch và key repeat.
- Build phải bật warning-as-error và static analysis.

## 10. Performance requirements

- Không file I/O, SQLite, JSON, network hoặc synchronous logging trong key path.
- Dùng fixed-size event/result buffer.
- P95 xử lý engine dưới 0,1 ms trong benchmark contract.
- Idle CPU gần 0%.
- Service khởi động độc lập với Settings.

## 11. Error and recovery

TSF/IMM32 registration lỗi, focus mất, host reject, IPC timeout, service crash, config hỏng và sleep/resume đều phải có fallback, reset/reconnect hoặc pass-through; không được làm kẹt bàn phím.

## 12. Compatibility rule

Windows chỉ gọi API hiện có của `port/skey-capi` hoặc bổ sung wrapper mới trong `windows/`. Không thay thế API cũ và không sửa cấu trúc `src/`, `port/`, `macos/skey-app/`.

## 13. UI parity rule

Windows Settings phải có đủ nhóm feature tương ứng với macOS: Cleaner, Clipboard, Keyboard, Settings và Translator. Các nhóm Shared tương ứng gồm Core, Localization, Logging, Services, Settings, Shortcuts và UI. Native control/XAML có thể khác SwiftUI, nhưng command, model, state, default, locale key, theme mode và error state phải có mapping một-một. Danh sách bắt buộc được kiểm tra trong `shared-contracts/feature-parity.json` và test parity.
