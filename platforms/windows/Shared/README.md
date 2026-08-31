# Windows shared layer

Các model và service dùng chung giữa tray/settings. UI không import trực tiếp
keyboard-hook implementation; giao tiếp với `skey-tray` qua protocol IPC có version.

```text
Shared/
├── Contracts/
├── IPC/
├── Localization/
├── Settings/
├── Theme/
└── typing-vectors/
```
