#include "KeyInjector.h"

#include <algorithm>
#include <cstddef>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmsystem.h>
#endif

namespace skey::windows {

std::vector<uint16_t> KeyInjector::utf8_to_utf16(const std::string& utf8) {
    std::vector<uint16_t> out;
    out.reserve(utf8.size());
    std::size_t i = 0;
    while (i < utf8.size()) {
        const auto b0 = static_cast<uint8_t>(utf8[i]);
        char32_t cp = 0;
        int extra = 0;
        if (b0 < 0x80) { cp = b0; }
        else if ((b0 & 0xE0) == 0xC0) { cp = b0 & 0x1F; extra = 1; }
        else if ((b0 & 0xF0) == 0xE0) { cp = b0 & 0x0F; extra = 2; }
        else if ((b0 & 0xF8) == 0xF0) { cp = b0 & 0x07; extra = 3; }
        else { ++i; continue; }  // invalid lead byte

        if (i + extra >= utf8.size()) break;
        bool valid = true;
        for (int k = 1; k <= extra; ++k) {
            const auto b = static_cast<uint8_t>(utf8[i + k]);
            if ((b & 0xC0) != 0x80) { valid = false; break; }
            cp = (cp << 6) | (b & 0x3F);
        }
        i += extra + 1;
        if (!valid) continue;

        if (cp >= 0x10000) {
            cp -= 0x10000;
            out.push_back(static_cast<uint16_t>(0xD800 + (cp >> 10)));
            out.push_back(static_cast<uint16_t>(0xDC00 + (cp & 0x3FF)));
        } else {
            out.push_back(static_cast<uint16_t>(cp));
        }
    }
    return out;
}

#ifdef _WIN32

namespace {

// Sleep(1) only resolves to ~1-2ms when the system timer resolution is
// raised; otherwise it waits ~15ms and typing would stutter.
void ensure_high_resolution_timer() {
    static const bool done = [] {
        timeBeginPeriod(1);
        return true;
    }();
    (void)done;
}

void send_backspace() {
    INPUT inputs[2]{};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_BACK;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = VK_BACK;
    inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, inputs, sizeof(INPUT));
}

} // namespace

void KeyInjector::inject(int backspaces, const std::string& utf8_text) {
    ensure_high_resolution_timer();

    for (int i = 0; i < backspaces; ++i) {
        send_backspace();
        Sleep(1);  // ~1.2ms inter-backspace delay
    }
    if (backspaces > 0) Sleep(2);  // settle before inserting

    const auto units = utf8_to_utf16(utf8_text);
    constexpr std::size_t chunk_size = 32;
    for (std::size_t offset = 0; offset < units.size(); offset += chunk_size) {
        const std::size_t n = std::min(chunk_size, units.size() - offset);
        std::vector<INPUT> inputs;
        inputs.reserve(n * 2);
        for (std::size_t j = 0; j < n; ++j) {
            INPUT down{};
            down.type = INPUT_KEYBOARD;
            down.ki.wScan = units[offset + j];
            down.ki.dwFlags = KEYEVENTF_UNICODE;
            INPUT up = down;
            up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
            inputs.push_back(down);
            inputs.push_back(up);
        }
        SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
        if (offset + n < units.size()) Sleep(1);  // ~1ms inter-chunk delay
    }
}

#else // Non-Windows: no-op (tests exercise utf8_to_utf16 only).

void KeyInjector::inject(int, const std::string&) {}

#endif

} // namespace skey::windows
