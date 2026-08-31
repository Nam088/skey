# Windows IME Task Board

Branch: `windows-ime`

## Quy tắc bắt buộc

- Chỉ thêm file/folder mới.
- Không di chuyển, đổi tên, xóa hoặc sửa mục đích code hiện tại.
- MacOS là behavior reference.
- Rust core/C ABI hiện tại là dependency dùng chung.
- Mỗi task phải có test và acceptance criteria.
- Không merge task nếu build/test hiện tại bị ảnh hưởng.

## W0 — Baseline và contract

- [x] W0.1 Chốt module map từ `macos/skey-app`.
- [x] W0.2 Chốt event contract cho key, backspace, composition, commit, reset.
- [x] W0.3 Chốt config, IPC, locale và theme schema.
- [x] W0.4 Tạo test vectors dùng chung.
- [ ] W0.5 Ghi baseline Rust/macOS build và test.

Acceptance: có spec, schema, vector format và baseline reproducible.

## W1 — Core bridge và fake host

- [x] W1.1 Tạo wrapper C++ quanh `skey-capi`.
- [x] W1.2 Tạo `EditResult` và fixed-size event contract.
- [x] W1.3 Tạo fake text host.
- [x] W1.4 Viết contract tests cho Telex/VNI/backspace/reset.
- [x] W1.5 Kiểm tra pass-through và host rejection recovery.

Acceptance: adapter test chạy không cần Windows UI và kết quả khớp vector Rust.

## W2 — TSF service

- [x] W2.1 Tạo COM class và TSF profile registration (skeleton).
- [x] W2.2 Implement `ITfTextInputProcessor` (skeleton).
- [x] W2.3 Implement `ITfKeyEventSink` (skeleton).
- [x] W2.4 Implement composition lifecycle (portable pipeline wiring).
- [ ] W2.5 Implement context/selection tracking.
- [ ] W2.6 Implement timeout, focus-loss và recovery.

Acceptance: gõ đúng trong Notepad trên Windows CI/VM.

## W3 — IMM32 fallback

- [ ] W3.1 Tạo IMM32 adapter.
- [ ] W3.2 Dùng chung engine và contract test.
- [ ] W3.3 Routing TSF/IMM32 theo capability của ứng dụng.

Acceptance: ứng dụng legacy nhận đúng output và không bị duplicate input.

## W4 — Tray và IPC

- [x] W4.1 Tạo `skey-tray.exe` Win32 tối giản.
- [x] W4.2 Tạo named-pipe protocol có version/timeout.
- [x] W4.3 Toggle Việt/Anh, status và restart service.
- [x] W4.4 Test service crash/reconnect.
- [x] W4.5 Add IPC command dispatcher for status/language/restart.

Acceptance: tray không làm ảnh hưởng hot path; service restart an toàn.

## W5 — Settings UI

- [x] W5.1 Tạo `skey-settings.exe` WinUI 3 (skeleton).
- [x] W5.2 Port model Settings theo feature structure của macOS.
- [x] W5.3 Implement locale/theme/input method/shortcut/macro.
- [ ] W5.4 Implement import/export và migration.
- [x] W5.5 Viết ViewModel tests.

Acceptance: Settings chạy độc lập, lưu/khôi phục đầy đủ và không truy cập trực tiếp engine.

## W6 — Localization/theme/accessibility

- [x] W6.1 Validate key parity vi/en.
- [x] W6.2 Implement system/light/dark.
- [x] W6.3 Test High Contrast, scale, keyboard navigation và Narrator (UI contract coverage).
- [x] W6.4 Test runtime locale/theme switch.

Acceptance: locale/theme matrix pass trên CI desktop.

## W7 — Compatibility/E2E

- [x] W7.1 Notepad/WordPad (contract coverage; desktop execution on Windows CI).
- [ ] W7.2 Edge/Chrome/Chromium.
- [ ] W7.3 VS Code/Terminal.
- [ ] W7.4 Office nếu môi trường có.
- [ ] W7.5 App switch, sleep/resume, RDP và key repeat.

Acceptance: không duplicate, mất ký tự, dính buffer hoặc kẹt keyboard.

## W8 — Packaging/release

- [ ] W8.1 MSIX/MSI.
- [ ] W8.2 TSF registration/unregistration.
- [ ] W8.3 Code signing/checksum.
- [ ] W8.4 Upgrade, rollback, uninstall.
- [ ] W8.5 Reproducible release artifacts.

Acceptance: cài/update/gỡ sạch và giữ config đúng yêu cầu.

## Definition of Done

Task chỉ hoàn thành khi có code, test, log kết quả và không làm thay đổi behavior của các platform hiện tại.
