#pragma once

namespace skey::windows {

// "Launch at login" via HKCU\Software\Microsoft\Windows\CurrentVersion\Run,
// the unpackaged-app equivalent of macOS SMAppService.mainApp.
class LaunchAtLogin {
public:
    // Idempotent: reads the current state first and only writes on change.
    static bool set_enabled(bool enabled);
    static bool enabled();
};

} // namespace skey::windows
