# Windows shared layer

Các model và service dùng chung giữa tray/settings. Không import TSF implementation vào UI; giao tiếp với `skey-ime` qua protocol IPC có version.

```text
Shared/
├── Contracts/
├── Localization/
├── Logging/
├── Services/
├── Settings/
├── Shortcuts/
└── UI/
```

