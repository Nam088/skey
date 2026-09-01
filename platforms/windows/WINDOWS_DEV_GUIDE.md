# SKey Windows - Hướng dẫn build và phát triển

SKey trên Windows dùng kiến trúc keyboard hook cổ điển:
một process duy nhất (`skey-tray.exe`) cài `WH_KEYBOARD_LL`, nuốt phím qua
engine Rust (`skey-capi`) và gửi lại kết quả bằng `SendInput`
(`KEYEVENTF_UNICODE`). Không có IME DLL, không regsvr32, không gạch chân
composition.

## Yêu cầu hệ thống

- Windows 10/11
- Visual Studio 2022 (Community trở lên)
- CMake 3.20+
- Rust toolchain (rustup) — để build `skey.lib`
- Git

## Cài đặt

### 1. Cài Visual Studio

Tải từ: https://visualstudio.microsoft.com/

Khi cài, chọn các workload:
- **Desktop development with C++**
- **Windows SDK** (thường cài kèm)

### 2. Cài CMake

```powershell
winget install Kitware.CMake
```

### 3. Cài Rust

```powershell
winget install Rustlang.Rustup
```

### 4. Clone repository

```cmd
git clone https://github.com/Nam088/skey.git
cd skey
```

## Build

### Cách 1: Dùng script (khuyến nghị)

```cmd
cd platforms\windows
build-windows.bat all
```

Script sẽ tự động:
- Build Rust core (`skey.lib`) qua cargo
- Clean build directory
- Configure CMake (`build-config/`)
- Build tất cả targets
- Chạy tests

### Cách 2: Thủ công

```cmd
cd core
cargo rustc --release -p skey-capi --target x86_64-pc-windows-msvc --crate-type staticlib
cd ..\platforms\windows
cmake -S build-config -B build -DSKEY_BUILD_TESTS=ON
cmake --build build --config Release
```

## Chạy tests

```cmd
cd platforms\windows\build
ctest -C Release --output-on-failure
```

## Cấu trúc project

```
platforms/windows/
├── skey-tray/          # Tray app + bộ gõ (1 process duy nhất)
│   ├── Hook/           # WH_KEYBOARD_LL + watchdog, LUT phân loại phím, modifier tracking
│   ├── Pipeline/       # 10 tầng xử lý (port từ macOS TypingPipeline), SendInput injector, hotkeys
│   └── Engine/         # wrapper skey-capi (Rust) + macro expansion
├── skey-settings/      # Settings UI (WinUI 3)
├── Shared/             # Shared contracts và services (IPC, settings, localization)
├── Tests/              # Unit tests
└── build-windows.bat   # Build script
```

## Test trên Windows

### 1. Build project

```cmd
cd platforms\windows
build-windows.bat all
```

### 2. Chạy tray app

```cmd
cd build\skey-tray\Release
skey-tray.exe
```

### 3. Test gõ

- Mở Notepad hoặc bất kỳ ứng dụng nào
- Click trái vào icon tray để toggle Vietnamese/English
- Hotkey mặc định: **Alt+Z** toggle ngôn ngữ
- Thử gõ Telex: `ddasnh` → `đánh`

Không cần register gì thêm — hook được cài khi `skey-tray.exe` chạy.

## Troubleshooting

### Lỗi: "CMake not found"

```powershell
winget install Kitware.CMake
```

### Lỗi: "skey.lib not found" khi build

Build Rust core trước:
```cmd
cd core
cargo rustc --release -p skey-capi --target x86_64-pc-windows-msvc --crate-type staticlib
```

### Gõ không ra tiếng Việt

1. Kiểm tra icon tray hiển thị chữ **V** (chế độ Việt)
2. Ứng dụng elevated (Run as Admin) cần SKey chạy với quyền tương đương
3. Hook có thể bị Windows gỡ ngầm — watchdog sẽ tự cài lại mỗi 2 giây

## Phát triển

### Thêm feature mới

1. Code trong thư mục tương ứng
2. Viết test trong `Tests/`
3. Chạy `build-windows.bat test` để verify
4. Commit và push

### Debug

```cmd
cmake -S build-config -B build -G "Visual Studio 17 2022" -DSKEY_BUILD_TESTS=ON
```

Mở `build/SKeyWindows.sln` và debug từ IDE. Lưu ý: callback hook chạy trên
thread riêng của hook, không phải UI thread.

## CI/CD

Mỗi push lên `main` (thay đổi `platforms/windows/`, `core/`, `shared/`) sẽ
trigger CI: build Rust core, build C++, chạy tests, đóng gói artifact.
Release tự động tạo tag `win-v*` và MSI installer (WiX v5).

Xem kết quả tại: https://github.com/Nam088/skey/actions

## Tài liệu tham khảo

- [Low-Level Keyboard Hooks (WH_KEYBOARD_LL)](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelkeyboardproc)
- [SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)
- [WinUI 3 Documentation](https://docs.microsoft.com/en-us/windows/apps/winui/)

## Hỗ trợ

Có vấn đề? Tạo issue tại: https://github.com/Nam088/skey/issues
