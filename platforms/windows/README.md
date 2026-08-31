# Windows frontend

Windows frontend được tổ chức tương ứng với `macos/skey-app`, nhưng dùng implementation native của Windows.

```text
windows/
├── skey-tray/      # tray + bộ gõ: WH_KEYBOARD_LL hook, pipeline, engine
├── skey-settings/  # Settings UI, tương đương Features/Settings
├── Shared/         # models, services, settings, localization, theme
└── Tests/          # unit, integration và UI contract tests
```

Không di chuyển hoặc đổi tên bất kỳ thư mục hiện có nào. Mọi code Windows mới chỉ được thêm trong `windows/` và gọi `port/skey-capi` qua wrapper.

