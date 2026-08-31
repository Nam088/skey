#pragma once

#include "../Models/InputContracts.h"
#include <cstdint>

namespace skey::windows {

inline EventKind classify_event_kind(std::uint32_t vk_key) noexcept {
    if (vk_key == 0x08) return EventKind::backspace;
    if (vk_key == 0x20 || vk_key == 0x0D || vk_key == 0x09) return EventKind::word_break;
    if (vk_key == 0x1B || vk_key == 0x25 || vk_key == 0x26 || vk_key == 0x27 || vk_key == 0x28 ||
        vk_key == 0x24 || vk_key == 0x23 || vk_key == 0x21 || vk_key == 0x22)
        return EventKind::navigation;
    return EventKind::key_down;
}

inline std::uint32_t pack_modifiers(bool shift, bool ctrl, bool alt, bool caps) noexcept {
    return (shift ? 1u : 0u) | (ctrl ? 2u : 0u) | (alt ? 4u : 0u) | (caps ? 8u : 0u);
}

} // namespace skey::windows
