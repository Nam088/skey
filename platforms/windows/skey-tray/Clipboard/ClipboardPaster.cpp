#include "ClipboardPaster.h"

#include "../Pipeline/KeyInjector.h"

#include <cstddef>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

#ifdef _WIN32

bool ClipboardPaster::paste_text(const std::string& utf8) {
    const std::vector<uint16_t> units = KeyInjector::utf8_to_utf16(utf8);

    if (OpenClipboard(nullptr) == FALSE) return false;
    bool written = false;
    if (EmptyClipboard()) {
        const SIZE_T bytes = (units.size() + 1) * sizeof(wchar_t);
        const HANDLE memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
        if (memory != nullptr) {
            auto* target = static_cast<wchar_t*>(GlobalLock(memory));
            if (target != nullptr) {
                for (std::size_t i = 0; i < units.size(); ++i) target[i] = static_cast<wchar_t>(units[i]);
                target[units.size()] = L'\0';
                GlobalUnlock(memory);
                written = SetClipboardData(CF_UNICODETEXT, memory) != nullptr;
            }
            if (!written) GlobalFree(memory);
        }
    }
    CloseClipboard();
    if (!written) return false;

    // Give the foreground app time to observe the new clipboard content,
    // mirroring the macOS 50ms settle before synthesizing the paste.
    Sleep(50);

    INPUT inputs[4]{};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'V';
    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'V';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(4, inputs, sizeof(INPUT)) == 4;
}

#else

bool ClipboardPaster::paste_text(const std::string&) { return false; }

#endif

} // namespace skey::windows
