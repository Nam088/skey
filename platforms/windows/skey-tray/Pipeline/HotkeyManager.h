#pragma once

#include <cstdint>

namespace skey::windows {

enum class HotkeyAction : uint8_t {
    none,
    toggle_language,
    clipboard,
    cleaner,
    ai,
    translate,
};

struct Hotkey {
    unsigned vk = 0;      // 0 = modifier-only chord (no regular key)
    uint8_t modifiers = 0;  // ModifierBits, excluding the caps bit
};

// Hotkey matching, ported from macOS ShortcutSettings defaults:
// language toggle Alt+Z, clipboard Alt+V, cleaner Alt+Shift+K,
// AI Alt+Space, quick translate Alt+T.
class HotkeyManager {
public:
    HotkeyManager();

    void set_hotkey(HotkeyAction action, Hotkey hotkey) noexcept;
    void set_cleaner_enabled(bool enabled) noexcept { cleaner_enabled_ = enabled; }

    // `mods` must already exclude the caps-lock bit.
    HotkeyAction match(unsigned vk, uint8_t mods) const noexcept;

    bool language_is_modifier_only() const noexcept { return language_.vk == 0; }
    uint8_t language_modifiers() const noexcept { return language_.modifiers; }

    // Virtual key codes used by defaults (kept local so this header is
    // platform-independent).
    static constexpr unsigned kVkSpace = 0x20;
    static constexpr unsigned kVkZ = 0x5A;
    static constexpr unsigned kVkV = 0x56;
    static constexpr unsigned kVkK = 0x4B;
    static constexpr unsigned kVkT = 0x54;

private:
    Hotkey language_;
    Hotkey clipboard_;
    Hotkey cleaner_;
    Hotkey ai_;
    Hotkey translate_;
    bool cleaner_enabled_ = true;
};

} // namespace skey::windows
