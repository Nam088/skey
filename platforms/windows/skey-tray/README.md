# SKey tray

Process duy nhất của bộ gõ trên Windows: hiển thị tray icon, quản lý trạng thái
Việt/Anh, mở Settings và phục vụ IPC. Từ bản hook-based, tray đồng thời host
`WH_KEYBOARD_LL` + `SendInput` — không còn IME DLL riêng, không gạch chân
composition.

```text
skey-tray/
├── Hook/       # WH_KEYBOARD_LL + watchdog, LUT phân loại phím, modifier tracking
├── Pipeline/   # 10 tầng xử lý (port từ TypingPipeline.swift), injector, hotkeys
├── Engine/     # wrapper skey-capi (Rust) + macro expansion
├── TrayApp.cpp # wWinMain: tray icon, message loop
└── TrayRuntime # lifecycle: hook, IPC server, toggle Việt/Anh
```
