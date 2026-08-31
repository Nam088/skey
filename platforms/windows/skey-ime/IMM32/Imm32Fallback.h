#pragma once

#ifdef _WIN32
#include <windows.h>

namespace skey::windows {

// Legacy message adapter. It intentionally does not install a global hook;
// callers feed it messages received by their IME window/context.
class Imm32Fallback final {
public:
    bool HandleMessage(HWND window, UINT message, WPARAM w_param, LPARAM l_param,
                       LRESULT* result) noexcept;
};

} // namespace skey::windows
#endif
