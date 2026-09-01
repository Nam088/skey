#pragma once

#include "../../../Shared/Contracts/SettingsModel.h"

#include <optional>
#include <string>
#include <string_view>

namespace skey::windows {

namespace hotkey_mod {
constexpr unsigned shift = 1u << 0;
constexpr unsigned ctrl = 1u << 1;
constexpr unsigned alt = 1u << 2;
constexpr unsigned win = 1u << 3;
constexpr unsigned all = shift | ctrl | alt | win;
} // namespace hotkey_mod

struct HotkeyFormat final {
    static std::string format(const HotkeyRecord& record);
    static std::optional<HotkeyRecord> parse(std::string_view text);
    static std::string key_name(unsigned vk);
    static std::optional<unsigned> vk_for_name(std::string_view name);
    static bool is_modifier_only(const HotkeyRecord& record) { return record.vk == 0; }
};

} // namespace skey::windows
