#pragma once

#include "HotkeyFormat.h"

#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace skey::windows {

namespace hotkey_action {
constexpr std::string_view toggle_language = "toggleLanguage";
constexpr std::string_view clipboard = "clipboard";
constexpr std::string_view cleaner = "cleaner";
constexpr std::string_view ai = "ai";
constexpr std::string_view translate = "translate";
} // namespace hotkey_action

struct HotkeyPreset final {
    std::string id;
    std::string name;
    HotkeyRecord record;
};

struct HotkeyStore final {
    static constexpr std::string_view custom_id = "custom";

    static const std::vector<std::string>& action_order();
    static std::string action_display_key(std::string_view action);
    static const std::vector<HotkeyPreset>& presets_for(std::string_view action);
    static HotkeyRecord default_record(std::string_view action);
    static std::vector<HotkeyRecord> default_records();
    static std::string default_preset_id(std::string_view action);
    static std::string preset_id_for(std::string_view action, const HotkeyRecord& record);
    static bool same_hotkey(const HotkeyRecord& a, const HotkeyRecord& b);
    // Mirrors macOS ShortcutSettings.findConflict: skips the action being edited
    // and ignores the cleaner while it is disabled.
    static std::optional<std::string> find_conflict(const std::vector<HotkeyRecord>& records,
                                                    const HotkeyRecord& candidate,
                                                    std::string_view exclude_action,
                                                    bool cleaner_enabled);
    static std::vector<std::pair<std::size_t, std::size_t>> detect_conflicts(
        const std::vector<HotkeyRecord>& records, bool cleaner_enabled);
};

namespace excluded_apps {
// Canonical form for Windows process matching: trimmed, basename only,
// ".exe" stripped, lower-cased. Empty result means invalid input.
std::string normalize(std::string_view raw);
bool valid(std::string_view raw);
std::vector<std::string> dedupe(std::vector<std::string> apps);
std::vector<std::string> with_added(std::vector<std::string> apps, std::string_view addition);
} // namespace excluded_apps

} // namespace skey::windows
