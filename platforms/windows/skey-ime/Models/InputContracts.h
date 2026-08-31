#pragma once

#include <cstdint>
#include <string_view>

namespace skey::windows {

enum class EventKind : std::uint8_t {
    key_down,
    backspace,
    word_break,
    navigation,
    focus_changed,
    app_changed,
    reset,
};

struct KeyEvent final {
    EventKind kind{EventKind::key_down};
    std::uint32_t codepoint{0};
    std::uint32_t key_code{0};
    std::uint32_t modifiers{0};
    bool repeat{false};
};

struct EditResult final {
    bool handled{false};
    std::uint16_t backspaces{0};
    std::string_view text{};
    bool committed{false};
    bool reset{false};
};

} // namespace skey::windows
