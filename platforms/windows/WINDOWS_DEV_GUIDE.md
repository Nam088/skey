# SKey Windows IME - Hướng dẫn build và phát triển

## Yêu cầu hệ thống

- Windows 10/11
- Visual Studio 2022 (Community trở lên)
- CMake 3.20+
- Git

## Cài đặt

### 1. Cài Visual Studio

Tải từ: https://visualstudio.microsoft.com/

Khi cài, chọn các workload:
- **Desktop development with C++**
- **Windows SDK** (thường cài kèm)

### 2. Cài CMake

Tải từ: https://cmake.org/download/

Hoặc dùng winget:
```powershell
winget install Kitware.CMake
```

### 3. Clone repository

```cmd
git clone https://github.com/Nam088/skey.git
cd skey
git checkout windows-ime
```

## Build

### Cách 1: Dùng script (khuyến nghị)

```cmd
cd windows
build-windows.bat all
```

Script sẽ tự động:
- Clean build directory
- Configure CMake
- Build tất cả targets
- Chạy tests

### Cách 2: Thủ công

```cmd
cd windows
mkdir build
cd build
cmake .. -DSKEY_BUILD_TESTS=ON
cmake --build . --config Release
```

### Cách 3: Dùng Visual Studio

```cmd
cd windows
cmake -B build -G "Visual Studio 17 2022" -DSKEY_BUILD_TESTS=ON
```

Mở `build/SKeyWindows.sln` trong Visual Studio và build từ IDE.

## Chạy tests

```cmd
cd windows/build
ctest -C Release --output-on-failure
```

## Cấu trúc project

```
windows/
├── skey-ime/           # IME DLL (COM server + TSF)
│   ├── Registration/   # COM registration
│   ├── TSF/           # Text Services Framework
│   ├── Host/          # Text host implementation
│   └── Engine/        # Engine adapter
├── skey-tray/         # System tray application
├── skey-settings/     # Settings UI (WinUI 3)
├── Shared/            # Shared contracts và services
├── Tests/             # Unit tests
└── build-windows.bat  # Build script
```

## Test trên Windows

### 1. Build project

```cmd
cd windows
build-windows.bat all
```

### 2. Register IME (cần Admin)

```cmd
cd build\skey-ime\Release
regsvr32 skey-ime.dll
```

### 3. Chạy tray app

```cmd
cd build\skey-tray\Release
skey-tray.exe
```

### 4. Test gõ

- Mở Notepad hoặc bất kỳ ứng dụng nào
- Dùng **Ctrl+Shift** để toggle Vietnamese/English
- Thử gõ: `xin chao` → `xin chào`

### 5. Unregister IME (khi xong)

```cmd
regsvr32 /u skey-ime.dll
```

## Troubleshooting

### Lỗi: "CMake not found"

Cài CMake và thêm vào PATH:
```powershell
winget install Kitware.CMake
```

### Lỗi: "Visual Studio not found"

Cài Visual Studio 2022 với workload "Desktop development with C++"

### Lỗi: "Windows SDK not found"

Cài Windows SDK từ Visual Studio Installer

### IME không hoạt động

1. Kiểm tra DLL đã được register: `regsvr32 skey-ime.dll`
2. Restart ứng dụng hoặc log out/log in
3. Kiểm tra System Tray có icon SKey không
4. Thử dùng Ctrl+Shift để toggle

## Phát triển

### Thêm feature mới

1. Code trong thư mục tương ứng
2. Viết test trong `Tests/`
3. Chạy `build-windows.bat test` để verify
4. Commit và push

### Debug

Mở project trong Visual Studio:
```cmd
cmake -B build -G "Visual Studio 17 2022" -DSKEY_BUILD_TESTS=ON
```

Set breakpoint và debug từ IDE.

## CI/CD

Mỗi push lên branch `windows-ime` sẽ trigger CI:
- Build trên Windows latest
- Chạy tất cả tests
- Tạo artifact

Xem kết quả tại: https://github.com/Nam088/skey/actions

## Tài liệu tham khảo

- [TSF Documentation](https://docs.microsoft.com/en-us/windows/win32/tsf/text-services-framework)
- [COM Documentation](https://docs.microsoft.com/en-us/windows/win32/com/component-object-model-com)
- [WinUI 3 Documentation](https://docs.microsoft.com/en-us/windows/apps/winui/)

## Hỗ trợ

Có vấn đề? Tạo issue tại: https://github.com/Nam088/skey/issues
