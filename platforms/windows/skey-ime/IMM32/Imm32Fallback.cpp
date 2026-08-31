#ifdef _WIN32
#include "Imm32Fallback.h"
namespace skey::windows {
bool Imm32Fallback::HandleMessage(HWND, UINT message, WPARAM, LPARAM, LRESULT* result) noexcept {
    if (result == nullptr) return false;
    // Preserve all messages until a concrete host adapter is attached.
    if (message == WM_IME_STARTCOMPOSITION || message == WM_IME_ENDCOMPOSITION) {
        *result = 0;
        return false;
    }
    return false;
}
} // namespace skey::windows
#endif
