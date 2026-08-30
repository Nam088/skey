# SKey IME service

```text
skey-ime/
├── Context/          # TSF context, selection và focus
├── Engine/           # wrapper C++ quanh port/skey-capi
├── EventHandling/    # TSF key sink và event classification
│   └── Pipeline/     # pipeline tương ứng macOS TypingPipeline
├── Host/             # composition/text host adapters
├── Models/           # edit result, options, profile state
├── TSF/              # COM text service và language profile
├── IMM32/            # fallback cho ứng dụng legacy
└── Registration/     # COM/TSF registration
```

Engine algorithm không được viết lại ở đây; lớp này chỉ chuyển event Windows thành contract của Rust core.

TSF flow hiện có:

```text
Activate(thread manager)
  → AttachKeyEventSink(context, handler)
  → OnTestKeyDown
  → OnKeyDown
  → handler dispatches KeyEvent to CompositionHost
  → Deactivate
  → UnadviseSink + release COM references
```

`KeyEventSink` giữ pass-through cho key-up; key-down chỉ bị ăn khi handler
trả về `true`. Navigation/focus loss được chuyển thành reset event.
## Native Windows boundaries

`TSF/` contains the COM-facing `ITfTextInputProcessor` and
`ITfKeyEventSink` implementations. They are compiled only on `_WIN32` and
keep event routing separate from the portable engine. `IMM32/` is a passive
legacy adapter; it never installs a global keyboard hook. Registration entry
points live in `Registration/ProfileRegistrar.*` so installers can invoke them
without loading tray or settings UI.

The current skeleton intentionally passes through key events until a concrete
text-host adapter is connected. This makes the Windows target buildable in CI
before a Windows desktop is available.

Activation flow: call `TsfTextService::Activate` once per TSF thread manager,
then `AttachKeyEventSink(context)` for the focused context. Deactivation
unadvises and releases the sink/source and thread manager. Key sink callbacks
currently report `eaten = FALSE`, so applications retain normal input until
the portable composition adapter is wired in.
