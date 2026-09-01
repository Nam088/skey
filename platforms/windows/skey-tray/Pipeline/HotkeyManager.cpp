#include "HotkeyManager.h"

#include "../Hook/ModifierTracker.h"

namespace skey::windows {

HotkeyManager::HotkeyManager()
    : language_{kVkZ, kModAlt},
      clipboard_{kVkV, kModAlt},
      cleaner_{kVkK, static_cast<uint8_t>(kModAlt | kModShift)},
      ai_{kVkSpace, kModAlt},
      translate_{kVkT, kModAlt} {}

void HotkeyManager::set_hotkey(HotkeyAction action, Hotkey hotkey) noexcept {
    switch (action) {
    case HotkeyAction::toggle_language: language_ = hotkey; break;
    case HotkeyAction::clipboard: clipboard_ = hotkey; break;
    case HotkeyAction::cleaner: cleaner_ = hotkey; break;
    case HotkeyAction::ai: ai_ = hotkey; break;
    case HotkeyAction::translate: translate_ = hotkey; break;
    case HotkeyAction::none: break;
    }
}

HotkeyAction HotkeyManager::action_from_name(const std::string& name) noexcept {
    if (name == "toggleLanguage") return HotkeyAction::toggle_language;
    if (name == "clipboard") return HotkeyAction::clipboard;
    if (name == "cleaner") return HotkeyAction::cleaner;
    if (name == "ai") return HotkeyAction::ai;
    if (name == "translate") return HotkeyAction::translate;
    return HotkeyAction::none;
}

void HotkeyManager::apply_records(const std::vector<HotkeyRecord>& records) noexcept {
    for (const auto& record : records) {
        const HotkeyAction action = action_from_name(record.action);
        if (action == HotkeyAction::none) continue;
        Hotkey hk;
        hk.vk = record.vk;
        // Settings-side modifiers exclude the caps bit already (shift=1,
        // ctrl=2, alt=4), matching ModifierTracker bits.
        hk.modifiers = static_cast<uint8_t>(record.modifiers & 0x07u);
        set_hotkey(action, hk);
    }
}

HotkeyAction HotkeyManager::match(unsigned vk, uint8_t mods) const noexcept {
    const auto matches = [vk, mods](const Hotkey& hk) {
        return hk.vk == vk && hk.modifiers == mods;
    };

    if (language_.vk != 0 && matches(language_)) return HotkeyAction::toggle_language;
    if (matches(clipboard_)) return HotkeyAction::clipboard;
    if (cleaner_enabled_ && matches(cleaner_)) return HotkeyAction::cleaner;
    if (matches(ai_)) return HotkeyAction::ai;
    if (matches(translate_)) return HotkeyAction::translate;
    return HotkeyAction::none;
}

} // namespace skey::windows
