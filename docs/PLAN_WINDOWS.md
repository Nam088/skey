# Kế hoạch xây dựng bộ gõ Windows

## 1. Mục tiêu

Xây dựng bộ gõ tiếng Việt cho Windows dựa trên behavior reference của mã macOS hiện tại và dùng Rust core làm lõi đa nền tảng.

Mục tiêu sản phẩm:

- Hỗ trợ Telex, VNI, VIQR và Simple Telex.
- Hỗ trợ Unicode cùng các bảng mã tương thích hiện có.
- Hỗ trợ macro, keymap, spell check, modern tone, free marking và English restore.
- Chuyển Việt/Anh bằng shortcut.
- Reset đúng khi đổi ứng dụng, đổi ô nhập, selection, backspace hoặc phím điều hướng.
- Hoạt động trong Win32, UWP/WinUI, Chromium, Office, VS Code và Windows Terminal.
- Có tray app, Settings, localization, theme và update.
- Độ trễ thấp, CPU/RAM thấp, không phụ thuộc mạng.

## 2. Nguyên tắc kiến trúc

- **Bảo toàn cấu trúc hiện tại:** không di chuyển, đổi tên, xóa hoặc sửa mục đích của bất kỳ folder/file hiện có nào.
- **Chỉ được bổ sung:** toàn bộ Windows backend, test, contract, build và UI mới phải nằm trong các folder mới được thêm vào repository.
- **Không refactor xuyên thư mục cũ:** mã `src/`, `port/` và `macos/skey-app/` tiếp tục giữ nguyên vị trí; chỉ thêm adapter hoặc test bổ sung khi thật sự cần và không phá API hiện tại.
- **Tương thích ngược:** code mới gọi API hiện có của `port/skey-core`/`port/skey-capi`; mọi thay đổi API (nếu bắt buộc) phải bổ sung API mới, không thay thế API cũ.
- Mã macOS là behavior reference, không port nguyên UI AppKit/SwiftUI.
- `port/skey-core` là nguồn logic xử lý duy nhất.
- `port/skey-capi` là ABI dùng chung cho frontend.
- IME service, tray và Settings chạy tách process.
- TSF là backend chính; IMM32 là fallback cho ứng dụng cũ.
- Không dùng global keyboard hook làm cơ chế IME chính.
- Engine không biết UI, localization, theme, clipboard hoặc network.
- Mọi thay đổi behavior phải có test vector trước khi merge.
- Không xóa các thay đổi đang có trong repository nếu chưa được xác nhận.

## 3. Giai đoạn audit mã macOS

Đọc toàn bộ `macos/skey-app/Sources` và lập behavior contract cho:

- `SKeyEngine`.
- `TypingPipeline`.
- `EventTapManager`.
- `KeyEventSender`.
- `AccessibilityContextReader`.
- `AppFocusObserver`.
- Settings, shortcut, macro và excluded apps.
- Clipboard, tray, permission, update và localization.
- Theme, appearance và các trạng thái UI.

Mỗi contract phải ghi rõ:

```text
Input
Precondition
Event sequence
Expected output
Expected composition
Expected reset
Error/fallback behavior
```

Các điểm cần rà soát đặc biệt trên macOS:

- Force unwrap và force cast trong input/context/storage path.
- Quyền Accessibility và Input Monitoring.
- Event tap bị disable hoặc timeout.
- Race condition khi đổi ứng dụng.
- Selection trong Spotlight/Chromium.
- Database clipboard và migration.
- Build target macOS 14/26 không đồng nhất.
- Swift test chưa được chạy trong release workflow.

## 4. Chuẩn hóa Rust core và C ABI

Giữ lại:

```text
port/skey-core
port/skey-capi
port/oracle
port/difftest
```

Kiểm tra và cố định API:

- Tạo/hủy engine.
- Xử lý key.
- Backspace.
- Reset.
- Set input method.
- Set charset.
- Set options.
- Caps Lock/Shift state.
- Macro/keymap.
- Context và multi-instance.
- ABI version và error code.

Quy định rõ ownership memory, buffer size, encoding, thread-safety và thời gian sống của con trỏ trả về.

## 5. Test core trước khi viết Windows

### Unit test

- Telex, VNI, VIQR, Simple Telex.
- Dấu thanh, mũ, móc và `đ`.
- Caps Lock, Shift, viết hoa.
- Backspace, Delete, word break.
- Macro, keymap, spell check.
- Modern style, free marking, English restore.
- Unicode, emoji và surrogate pair.

### Golden test

Ví dụ bắt buộc:

```text
ddanh  -> đánh
keer   -> kẻ
chayj  -> chạy
ddi    -> đi
tieeng -> tiếng
```

Ngoài output cuối, phải kiểm tra từng bước: `handled`, số backspace, text output và composition state.

### Differential test

So sánh:

```text
C++ oracle = Rust core = C ABI
```

Chạy toàn bộ input method, charset, option matrix, random sequence, backspace sequence, mode change và macro/keymap sweep.

### Fuzz và benchmark

- Fuzz input bất kỳ và chuỗi phím dài.
- Kiểm tra không panic, không out-of-bounds, không leak.
- Đo latency p50/p95/p99.
- Đo startup, memory, allocation và throughput.
- Chạy riêng workload macro, backspace-heavy và key repeat.

## 6. Test contract cho Windows adapter

Trước TSF thật, tạo fake text host:

```cpp
class FakeTextHost {
public:
    void deletePrevious(int count);
    void insertText(std::wstring_view text);
    void replaceSelection(std::wstring_view text);
    void commit();
    void reset();
};
```

Test flow:

```text
key event -> Windows adapter -> Rust core -> fake text host -> expected state
```

Phải kiểm tra key pass-through, composition, commit, backspace, selection, reset, focus loss, host rejection và recovery.

## 7. Windows backend

### TSF service

Process:

```text
skey-ime.exe
```

Cấu trúc:

```text
windows/ime/
├── TsfTextService
├── KeyEventSink
├── CompositionManager
├── TextStoreAdapter
├── ContextTracker
├── ProfileRegistrar
└── ErrorRecovery
```

TSF chịu trách nhiệm nhận key event, theo dõi focus/context, tạo composition, cập nhật selection, commit text, reset và đăng ký language profile.

### IMM32 fallback

Dùng cùng Rust core cho ứng dụng legacy, chỉ thay đổi lớp text host và routing.

### Build target

- Debug và Release.
- x64 trước.
- ARM64 sau khi x64 ổn định.
- MSVC `/W4 /WX /permissive- /EHsc`.
- CMake Presets.
- Không nuốt lỗi build bằng `|| true`.

## 8. Tray và Settings

### Tray

Process:

```text
skey-tray.exe
```

Chức năng: trạng thái Việt/Anh, bật/tắt, chọn kiểu gõ, mở Settings, diagnostics và restart service.

### Settings

Khuyến nghị dùng WinUI 3, tách process:

```text
skey-settings.exe
```

ViewModel không phụ thuộc XAML. Giao tiếp với IME bằng named pipe hoặc local RPC.

Các màn hình: General, Keyboard, Shortcut, Macro, Excluded Apps, Clipboard, Appearance, Language, About/Update và Diagnostics.

## 9. Localization

Dùng key chung giữa Mac và Windows:

```text
settings.general.title
settings.keyboard.title
settings.appearance.title
settings.theme.system
settings.theme.light
settings.theme.dark
```

Windows dùng `.resw`, macOS dùng `.strings`.

Quy tắc:

- Không hard-code text trong code hoặc XAML.
- Locale hợp lệ: `vi-VN`, `en-US`.
- Locale khác dùng fallback English.
- Missing key, extra key và chuỗi rỗng phải fail CI.
- Kiểm tra text dài, Unicode, emoji và layout.
- Tray, Settings, notification và dialog phải đồng bộ locale.

Config mẫu:

```json
{
  "schemaVersion": 1,
  "locale": "vi-VN",
  "theme": "system"
}
```

## 10. Theme

Model dùng chung:

```text
system
light
dark
```

Dùng semantic tokens thay vì màu hard-code:

```text
background.primary
background.secondary
text.primary
text.secondary
border
accent
warning
error
success
```

Test System Light, System Dark, ép Light, ép Dark, đổi theme runtime, High Contrast, focus/disabled state, scale 100–200%, font lớn, màn hình nhỏ và multi-monitor.

IME service không chứa logic theme.

## 11. Settings, migration và dữ liệu

Phải hỗ trợ config mặc định, config thiếu field, field cũ, field sai kiểu, file hỏng, import/export, migration, backup và rollback.

Clipboard phải test plain text, rich text, ảnh, file, dữ liệu lớn, retention, excluded apps, search Unicode, pin/unpin, xóa dữ liệu, database corruption và concurrent events.

Không ghi API key, token hoặc dữ liệu nhạy cảm vào log.

## 12. UI test

### Unit/ViewModel

- Settings persistence và reset default.
- Shortcut conflict.
- Macro validation.
- Locale/theme selection.
- Excluded apps.
- Update/error state.
- Clipboard sorting/search/retention.

### UI automation

- Mở Settings và điều hướng tab.
- Đổi locale.
- Đổi theme.
- Đổi kiểu gõ.
- Tạo/sửa/xóa macro.
- Đổi shortcut.
- Tray menu.
- Import/export.
- Empty/loading/error state.
- Keyboard-only navigation.
- Narrator/High Contrast.

### End-to-end typing

Chạy trên Notepad, WordPad, Edge, Chrome, VS Code, Windows Terminal và Office nếu có:

```text
ddanh -> đánh
keer  -> kẻ
chayj -> chạy
ddi   -> đi
```

Chạy thêm gõ nhanh, gõ chậm, key repeat, app switch, focus loss, sleep/resume và RDP nếu có runner phù hợp.

## 13. Error recovery

Phải xử lý TSF registration lỗi, profile mất, service crash, IPC mất kết nối, config không đọc được, không có quyền ghi, database hỏng, host từ chối edit, Explorer restart, sleep/resume, RDP, update lỗi và mất mạng.

Nguyên tắc: không làm kẹt bàn phím, không crash vì dữ liệu người dùng, có fallback, log cục bộ, diagnostics, reset config và restart service.

## 14. CI/CD

### Linux

- Rust build/test.
- Differential sweep.
- Fuzz smoke.
- Locale/schema validation.

### macOS

- Rust test.
- `swift test`.
- Swift compile.
- App/package validation.
- Integration test khi có permission.

### Windows

- Rust build/test.
- CMake configure/build.
- TSF và IMM32 test.
- Tray và Settings build.
- CTest.
- Installer validation.
- UI smoke test trên desktop runner.

Nightly chạy differential sweep lớn, fuzz, benchmark và UI E2E.

## 15. Installer và update

Installer phải đăng ký TSF profile, hỗ trợ x64/ARM64, giữ config khi update, xóa profile khi uninstall, có checksum, code signing, rollback và không xóa nhầm dữ liệu người dùng.

## 16. Milestone

### M1 — Audit macOS

Behavior contract, module map, risk list và test vector.

### M2 — Core test

Golden, differential, fuzz, benchmark và C ABI test.

### M3 — Fake adapter

Fake text host, composition model và adapter contract test.

### M4 — TSF skeleton

COM registration, text service, key sink và context tracking.

### M5 — Kết nối Rust

Gõ được trong Notepad và pass contract test.

### M6 — IMM32

Fallback cho app cũ và shared test vector.

### M7 — Tray/Settings

Win32 tray, WinUI 3 Settings, IPC, localization, theme và storage.

### M8 — UI test

ViewModel, UI automation, accessibility, locale và theme matrix.

### M9 — Compatibility

Chromium, Office, VS Code, Terminal, app switch, sleep/resume.

### M10 — Release

Installer, signing, update, rollback, checksums và release artifacts.

## 17. Definition of Done

Chỉ hoàn thành khi:

- Core, differential và C ABI test pass.
- Mac build, Swift test và UI smoke pass.
- Windows TSF/IMM32 build và test pass.
- UI unit/UI automation pass.
- Localization/theme/migration test pass.
- Installer/update/rollback test pass.
- Không còn force unwrap/cast trong input, config và persistence path.
- Release build reproducible trên CI.
- Có diagnostics, artifact, checksum và rollback.

## 18. Cấu trúc tối ưu đề xuất

Repository hiện tại được giữ nguyên. Cấu trúc dưới đây là phần **chỉ bổ sung**, không phải yêu cầu di chuyển các folder cũ. Dependency chỉ được đi từ ngoài vào trong:

```text
UI / Tray / Platform adapter
            ↓
       Contracts
            ↓
          C ABI
            ↓
        Rust core
```

Cấu trúc chi tiết:

```text
unikey/                       # giữ nguyên toàn bộ nội dung hiện tại
├── src/                       # không di chuyển/sửa cấu trúc
├── port/                      # không di chuyển/sửa cấu trúc
├── macos/skey-app/            # không di chuyển/sửa cấu trúc
├── windows/                   # BỔ SUNG: Windows IME, tray, settings
│   ├── ime/
│   ├── tray/
│   ├── settings/
│   ├── host/
│   └── tests/
├── shared-contracts/          # BỔ SUNG: schema, protocol, enum, vectors
├── tests-windows/             # BỔ SUNG: Windows unit/integration/UI tests
├── build-windows/             # BỔ SUNG: CMake, presets, scripts
├── installer-windows/         # BỔ SUNG: MSIX/MSI và signing metadata
└── docs/                      # đã có, chỉ thêm tài liệu
```

Các folder hiện tại vẫn là nguồn tham chiếu:

```text
port/skey-core  → engine dùng chung, gọi qua API hiện có
port/skey-capi  → ABI dùng chung, chỉ bổ sung tương thích khi cần
macos/skey-app  → behavior reference và bản macOS đang chạy
src/            → C++ oracle/reference gốc
```

### 18.1. Tách process

Windows nên có ba process:

```text
skey-ime.exe       # TSF/IMM32, hot path, không UI
skey-tray.exe      # tray, shortcut global, lifecycle
skey-settings.exe  # WinUI 3, settings và diagnostics
```

Quy tắc:

- `skey-ime.exe` không link WinUI, WebView, SQLite UI hoặc network client.
- `skey-ime.exe` chỉ phụ thuộc `skey-capi` và Windows COM/TSF.
- `skey-tray.exe` giao tiếp với IME qua named pipe hoặc local RPC.
- `skey-settings.exe` chỉ giao tiếp qua shared contract, không truy cập trực tiếp engine.
- Service crash không được làm treo Settings; Settings crash không được làm mất trạng thái gõ.

### 18.2. Tối ưu hot path

Đường xử lý một phím phải là:

```text
TSF key event
→ fixed-size event struct
→ skey-core
→ fixed-size edit result
→ composition update/commit
```

Không được có trong hot path:

- File I/O.
- SQLite.
- JSON encode/decode.
- Localization lookup.
- Theme lookup.
- Network.
- Dynamic UI dispatch.
- Log đồng bộ.
- Allocation lặp lại nếu có thể tránh.

Log, metrics và diagnostics phải dùng queue bất đồng bộ hoặc ring buffer giới hạn kích thước.

Không được sửa trực tiếp hot path hiện tại trong `port/` hoặc `macos/` chỉ để phục vụ Windows. Windows adapter phải bao quanh API hiện có; nếu thiếu chức năng thì thêm API mới tương thích ở phần bổ sung và giữ nguyên API cũ.

### 18.3. Contract dùng chung

Đặt các enum và schema quan trọng trong `core/contracts`:

```text
InputMethod
Charset
ThemeMode
Locale
ShortcutAction
EditResult
EngineOptions
ConfigSchemaVersion
```

Từ một nguồn duy nhất, sinh hoặc kiểm tra:

- Rust types.
- C headers.
- C++ Windows types.
- Swift models.
- WinUI resource/key validator.

Mục tiêu là tránh việc Mac và Windows có enum hoặc default value khác nhau.

### 18.4. Đường build tối ưu

Build graph nên có các tầng độc lập:

```text
core tests
    ↓
C ABI tests
    ↓
platform adapter tests
    ↓
IME/service tests
    ↓
UI tests
    ↓
installer/release tests
```

Nếu chỉ sửa Rust core thì không cần build lại UI khi chạy local test. Nếu chỉ sửa UI thì không cần chạy differential sweep lớn.

Các preset tối thiểu:

```text
core-debug
core-release
windows-debug
windows-release
windows-asan
macos-debug
macos-release
```

### 18.5. Quy tắc module

- Core không import platform.
- Platform adapter không chứa thuật toán tiếng Việt.
- UI không tự xử lý key event.
- Storage không được gọi từ hot path.
- Localization không được nằm trong engine.
- Theme chỉ thuộc UI layer.
- Mỗi process có entry point và lifecycle riêng.
- Mỗi public API phải có test contract.
- Mỗi cross-process message phải có version.

### 18.6. Lựa chọn UI cuối cùng

- IME: C++ Win32/COM/TSF.
- Fallback: IMM32.
- Tray: Win32 nhẹ.
- Settings: WinUI 3, chạy process riêng.
- Localization: `.resw` trên Windows, `.strings` trên macOS.
- Theme: semantic tokens với `system/light/dark`.
- IPC: named pipe local, có protocol version và timeout.

Đây là cấu trúc tối ưu vì phần xử lý phím có ít dependency nhất, phần UI có thể thay đổi độc lập, Rust core được test trên mọi hệ điều hành và Windows CI có thể build toàn bộ dù không có máy Windows local.

## 19. Quy tắc thay đổi file bắt buộc

Trước mỗi commit Windows phải kiểm tra:

```bash
git diff --name-status
```

Chấp nhận:

- File mới trong `windows/`, `shared-contracts/`, `tests-windows/`, `build-windows/`, `installer-windows/` và `docs/`.
- File CI mới hoặc phần job Windows bổ sung.
- File cấu hình build mới.

Không chấp nhận:

- Di chuyển hoặc đổi tên folder/file hiện có.
- Xóa file hiện có.
- Đổi API cũ làm macOS/Rust hiện tại lỗi.
- Đưa dependency Windows vào `macos/skey-app`.
- Đưa UI hoặc storage vào `port/skey-core`.

Nếu cần dùng code hiện tại, Windows chỉ include/link qua interface hiện có hoặc tạo wrapper mới trong `windows/`.
