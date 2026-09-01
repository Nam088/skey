#include "InputProfile.h"

#include "../../Shared/TsfBridge/TsfBridge.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

#ifdef _WIN32

namespace {
HKL previous_layout = nullptr;
}

bool InputProfile::activate() {
    if (previous_layout != nullptr) return true;
    const HKL hkl = LoadKeyboardLayoutW(kSKeyTsfLayoutName, 0);
    if (hkl == nullptr) return false;  // profile not registered
    previous_layout = ActivateKeyboardLayout(hkl, 0);
    return true;
}

void InputProfile::restore() {
    if (previous_layout == nullptr) return;
    ActivateKeyboardLayout(previous_layout, 0);
    previous_layout = nullptr;
}

#else

bool InputProfile::activate() { return false; }
void InputProfile::restore() {}

#endif

} // namespace skey::windows
