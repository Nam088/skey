#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace skey::windows {

// SendInput-based injector: emits backspaces (VK_BACK down/up pairs) then
// replacement text as KEYEVENTF_UNICODE events. Injected events carry
// LLKHF_INJECTED, so the hook passes them through without recursion.
//
// Timing mirrors the macOS KeyEventSender: ~1.2ms between backspaces,
// 2ms settle before text, ~1ms between text chunks.
class KeyInjector {
public:
    // Pure UTF-8 -> UTF-16 conversion (platform-independent, unit-testable).
    static std::vector<uint16_t> utf8_to_utf16(const std::string& utf8);

    static void inject(int backspaces, const std::string& utf8_text);
};

} // namespace skey::windows
