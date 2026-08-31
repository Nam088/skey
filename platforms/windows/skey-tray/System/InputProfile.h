#pragma once

namespace skey::windows {

// Phase 5: switches the session's Windows input profile to the SKey TSF
// profile so TSF-aware apps (browsers) load skey-tsf.dll and the bridge can
// deliver engine results as TSF edits. Mirrors EVKey's use of
// LoadKeyboardLayoutW/ActivateKeyboardLayout when its IME option is on.
class InputProfile {
public:
    // Idempotent. Returns false when the profile is not registered (e.g.
    // running the portable exe without the installer), in which case the
    // caller simply keeps SendInput injection.
    static bool activate();
    static void restore();
};

} // namespace skey::windows
