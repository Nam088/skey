#include "HotkeyStore.h"

#include <algorithm>
#include <cctype>

namespace skey::windows {

namespace {

std::string preset_display(const HotkeyRecord& record) {
    std::string out;
    const auto append = [&out](std::string_view part) {
        if (!out.empty()) out += " + ";
        out += part;
    };
    if (record.modifiers & hotkey_mod::ctrl) append("Ctrl");
    if (record.modifiers & hotkey_mod::alt) append("Alt");
    if (record.modifiers & hotkey_mod::shift) append("Shift");
    if (record.modifiers & hotkey_mod::win) append("Win");
    if (record.vk != 0) append(HotkeyFormat::key_name(record.vk));
    return out;
}

HotkeyPreset make_preset(std::string id, unsigned vk, unsigned modifiers) {
    HotkeyRecord record{{}, vk, modifiers};
    return HotkeyPreset{std::move(id), preset_display(record), std::move(record)};
}

} // namespace

const std::vector<std::string>& HotkeyStore::action_order() {
    static const std::vector<std::string> actions{
        std::string{hotkey_action::toggle_language},
        std::string{hotkey_action::clipboard},
        std::string{hotkey_action::cleaner},
        std::string{hotkey_action::ai},
        std::string{hotkey_action::translate},
    };
    return actions;
}

std::string HotkeyStore::action_display_key(std::string_view action) {
    if (action == hotkey_action::toggle_language) return "keyboard.shortcut.toggleTitle";
    if (action == hotkey_action::clipboard) return "clipboard.option.shortcut";
    if (action == hotkey_action::cleaner) return "cleaner.option.shortcut";
    if (action == hotkey_action::ai) return "ai.option.shortcut";
    if (action == hotkey_action::translate) return "translator.option.shortcut";
    return {};
}

const std::vector<HotkeyPreset>& HotkeyStore::presets_for(std::string_view action) {
    // Preset ids and chord shapes mirror macOS ShortcutSettings, with
    // Option->Alt and Command->Win translations.
    static const std::vector<HotkeyPreset> language{
        make_preset("optZ", 0x5A, hotkey_mod::alt),
        make_preset("ctrlShift", 0, hotkey_mod::ctrl | hotkey_mod::shift),
        make_preset("ctrlOptionZ", 0x5A, hotkey_mod::ctrl | hotkey_mod::alt),
        make_preset("cmdShift", 0, hotkey_mod::win | hotkey_mod::shift),
        make_preset("optionShift", 0, hotkey_mod::alt | hotkey_mod::shift),
        make_preset("ctrlSpace", 0x20, hotkey_mod::ctrl),
    };
    static const std::vector<HotkeyPreset> clipboard{
        make_preset("optV", 0x56, hotkey_mod::alt),
        make_preset("cmdShiftV", 0x56, hotkey_mod::win | hotkey_mod::shift),
        make_preset("ctrlOptionV", 0x56, hotkey_mod::ctrl | hotkey_mod::alt),
        make_preset("optC", 0x43, hotkey_mod::alt),
    };
    static const std::vector<HotkeyPreset> cleaner{
        make_preset("optShiftK", 0x4B, hotkey_mod::alt | hotkey_mod::shift),
        make_preset("optShiftC", 0x43, hotkey_mod::alt | hotkey_mod::shift),
        make_preset("ctrlOptionK", 0x4B, hotkey_mod::ctrl | hotkey_mod::alt),
    };
    static const std::vector<HotkeyPreset> ai{
        make_preset("optSpace", 0x20, hotkey_mod::alt),
        make_preset("ctrlOptionSpace", 0x20, hotkey_mod::ctrl | hotkey_mod::alt),
        make_preset("cmdShiftSpace", 0x20, hotkey_mod::win | hotkey_mod::shift),
    };
    static const std::vector<HotkeyPreset> none{};
    if (action == hotkey_action::toggle_language) return language;
    if (action == hotkey_action::clipboard) return clipboard;
    if (action == hotkey_action::cleaner) return cleaner;
    if (action == hotkey_action::ai) return ai;
    return none;
}

HotkeyRecord HotkeyStore::default_record(std::string_view action) {
    if (action == hotkey_action::toggle_language) return HotkeyRecord{std::string{hotkey_action::toggle_language}, 0x5A, hotkey_mod::alt};
    if (action == hotkey_action::clipboard) return HotkeyRecord{std::string{hotkey_action::clipboard}, 0x56, hotkey_mod::alt};
    if (action == hotkey_action::cleaner) return HotkeyRecord{std::string{hotkey_action::cleaner}, 0x4B, hotkey_mod::alt | hotkey_mod::shift};
    if (action == hotkey_action::ai) return HotkeyRecord{std::string{hotkey_action::ai}, 0x20, hotkey_mod::alt};
    if (action == hotkey_action::translate) return HotkeyRecord{std::string{hotkey_action::translate}, 0x54, hotkey_mod::alt};
    return {};
}

std::vector<HotkeyRecord> HotkeyStore::default_records() {
    std::vector<HotkeyRecord> records;
    for (const auto& action : action_order()) {
        records.push_back(default_record(action));
    }
    return records;
}

std::string HotkeyStore::default_preset_id(std::string_view action) {
    if (action == hotkey_action::toggle_language) return "optZ";
    if (action == hotkey_action::clipboard) return "optV";
    if (action == hotkey_action::cleaner) return "optShiftK";
    if (action == hotkey_action::ai) return "optSpace";
    return std::string{custom_id};
}

std::string HotkeyStore::preset_id_for(std::string_view action, const HotkeyRecord& record) {
    for (const auto& preset : presets_for(action)) {
        if (same_hotkey(preset.record, record)) return preset.id;
    }
    return std::string{custom_id};
}

bool HotkeyStore::same_hotkey(const HotkeyRecord& a, const HotkeyRecord& b) {
    return a.vk == b.vk && a.modifiers == b.modifiers;
}

std::optional<std::string> HotkeyStore::find_conflict(const std::vector<HotkeyRecord>& records,
                                                      const HotkeyRecord& candidate,
                                                      std::string_view exclude_action,
                                                      bool cleaner_enabled) {
    for (const auto& record : records) {
        if (record.action == exclude_action) continue;
        if (!cleaner_enabled && record.action == hotkey_action::cleaner) continue;
        if (same_hotkey(record, candidate)) return record.action;
    }
    return std::nullopt;
}

std::vector<std::pair<std::size_t, std::size_t>> HotkeyStore::detect_conflicts(
    const std::vector<HotkeyRecord>& records, bool cleaner_enabled) {
    std::vector<std::pair<std::size_t, std::size_t>> conflicts;
    const auto active = [cleaner_enabled](const HotkeyRecord& record) {
        return cleaner_enabled || record.action != hotkey_action::cleaner;
    };
    for (std::size_t i = 0; i < records.size(); ++i) {
        if (!active(records[i])) continue;
        for (std::size_t j = i + 1; j < records.size(); ++j) {
            if (!active(records[j])) continue;
            if (same_hotkey(records[i], records[j])) conflicts.emplace_back(i, j);
        }
    }
    return conflicts;
}

namespace excluded_apps {

namespace {

bool is_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

} // namespace

std::string normalize(std::string_view raw) {
    while (!raw.empty() && is_space(raw.front())) raw.remove_prefix(1);
    while (!raw.empty() && is_space(raw.back())) raw.remove_suffix(1);
    if (raw.empty()) return {};
    const auto slash = raw.find_last_of("/\\");
    if (slash != std::string_view::npos) raw = raw.substr(slash + 1);
    std::string out(raw);
    if (out.size() > 4) {
        const auto suffix = std::string_view{out}.substr(out.size() - 4);
        bool is_exe = true;
        const char* expected = ".exe";
        for (std::size_t i = 0; i < 4; ++i) {
            if (std::tolower(static_cast<unsigned char>(suffix[i])) != expected[i]) {
                is_exe = false;
                break;
            }
        }
        if (is_exe) out.erase(out.size() - 4);
    }
    for (auto& c : out) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return out;
}

bool valid(std::string_view raw) { return !normalize(raw).empty(); }

std::vector<std::string> dedupe(std::vector<std::string> apps) {
    std::vector<std::string> out;
    for (auto& app : apps) {
        auto name = normalize(app);
        if (name.empty()) continue;
        if (std::find(out.begin(), out.end(), name) != out.end()) continue;
        out.push_back(std::move(name));
    }
    return out;
}

std::vector<std::string> with_added(std::vector<std::string> apps, std::string_view addition) {
    auto name = normalize(addition);
    if (name.empty()) return apps;
    if (std::find(apps.begin(), apps.end(), name) != apps.end()) return apps;
    apps.push_back(std::move(name));
    return apps;
}

} // namespace excluded_apps

} // namespace skey::windows
