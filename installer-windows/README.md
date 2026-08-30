# Windows packaging boundary

The `skey-package` target stages the Windows tray binary and emits a zip
artifact in CI. It is intentionally unsigned and does not register a TSF
profile. Release signing, MSIX metadata, and registration are separate steps
so a package build remains deterministic on `windows-latest`.
