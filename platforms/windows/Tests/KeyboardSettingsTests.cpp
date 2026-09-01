#include "../skey-settings/Shared/Shortcuts/HotkeyFormat.h"
#include "../skey-settings/Shared/Shortcuts/HotkeyStore.h"
#include "../skey-settings/Shared/Shortcuts/ShortcutRecorderModel.h"
#include "../Shared/Settings/SettingsStore.h"

#include <cassert>
#include <cstdio>
#include <filesystem>
#include <string>
#include <vector>

using namespace skey::windows;

namespace {

bool same(const HotkeyRecord& a, unsigned vk, unsigned modifiers) {
    return a.vk == vk && a.modifiers == modifiers;
}

void test_format_and_parse() {
    assert(HotkeyFormat::format({"toggleLanguage", 0x5A, hotkey_mod::alt}) == "Alt+Z");
    assert(HotkeyFormat::format({"cleaner", 0x4B, hotkey_mod::alt | hotkey_mod::shift}) == "Alt+Shift+K");
    assert(HotkeyFormat::format({"x", 0x20, hotkey_mod::alt}) == "Alt+Space");
    assert(HotkeyFormat::format({"x", 0, hotkey_mod::ctrl | hotkey_mod::shift}) == "Ctrl+Shift");
    assert(HotkeyFormat::format({"x", 0x5A, hotkey_mod::ctrl | hotkey_mod::alt}) == "Ctrl+Alt+Z");
    assert(HotkeyFormat::format({"x", 0, hotkey_mod::win | hotkey_mod::shift}) == "Shift+Win");
    assert(HotkeyFormat::format({"x", 0, 0}) == "");

    for (const auto& record : HotkeyStore::default_records()) {
        const auto back = HotkeyFormat::parse(HotkeyFormat::format(record));
        assert(back.has_value());
        assert(back->vk == record.vk);
        assert(back->modifiers == record.modifiers);
    }

    for (const auto& action : HotkeyStore::action_order()) {
        for (const auto& preset : HotkeyStore::presets_for(action)) {
            const auto back = HotkeyFormat::parse(HotkeyFormat::format(preset.record));
            assert(back.has_value());
            assert(back->vk == preset.record.vk);
            assert(back->modifiers == preset.record.modifiers);
        }
    }

    const auto reordered = HotkeyFormat::parse("shift+ALT+k");
    assert(reordered.has_value() && same(*reordered, 0x4B, hotkey_mod::alt | hotkey_mod::shift));

    const auto spaced = HotkeyFormat::parse("Alt + Z");
    assert(spaced.has_value() && same(*spaced, 0x5A, hotkey_mod::alt));

    const auto mac_style = HotkeyFormat::parse("Option+V");
    assert(mac_style.has_value() && same(*mac_style, 0x56, hotkey_mod::alt));

    assert(HotkeyFormat::parse("Ctrl+Shift").has_value());
    assert(HotkeyFormat::parse("Ctrl+Shift")->vk == 0);
    assert(HotkeyFormat::parse("Alt+Num +").has_value());
    assert(HotkeyFormat::parse("Alt+Num +")->vk == 0x6B);
    assert(HotkeyFormat::parse("F9").has_value());
    assert(HotkeyFormat::parse("F9")->vk == 0x78);
    assert(HotkeyFormat::parse("Key(123)").has_value());
    assert(HotkeyFormat::parse("Key(123)")->vk == 123);

    assert(!HotkeyFormat::parse("").has_value());
    assert(!HotkeyFormat::parse("   ").has_value());
    assert(!HotkeyFormat::parse("Alt+").has_value());
    assert(!HotkeyFormat::parse("+").has_value());
    assert(!HotkeyFormat::parse("Nope").has_value());
    assert(!HotkeyFormat::parse("Alt+Z+X").has_value());

    const auto single_mod = HotkeyFormat::parse("Shift");
    assert(single_mod.has_value() && single_mod->vk == 0);
    assert(single_mod->modifiers == hotkey_mod::shift);
}

void test_presets_match_macos() {
    const auto& language = HotkeyStore::presets_for(hotkey_action::toggle_language);
    assert(language.size() == 6);
    assert(language[0].id == "optZ" && same(language[0].record, 0x5A, hotkey_mod::alt));
    assert(language[1].id == "ctrlShift" && same(language[1].record, 0, hotkey_mod::ctrl | hotkey_mod::shift));
    assert(language[2].id == "ctrlOptionZ" && same(language[2].record, 0x5A, hotkey_mod::ctrl | hotkey_mod::alt));
    assert(language[3].id == "cmdShift" && same(language[3].record, 0, hotkey_mod::win | hotkey_mod::shift));
    assert(language[4].id == "optionShift" && same(language[4].record, 0, hotkey_mod::alt | hotkey_mod::shift));
    assert(language[5].id == "ctrlSpace" && same(language[5].record, 0x20, hotkey_mod::ctrl));

    const auto& clipboard = HotkeyStore::presets_for(hotkey_action::clipboard);
    assert(clipboard.size() == 4);
    assert(clipboard[0].id == "optV" && same(clipboard[0].record, 0x56, hotkey_mod::alt));
    assert(clipboard[1].id == "cmdShiftV" && same(clipboard[1].record, 0x56, hotkey_mod::win | hotkey_mod::shift));
    assert(clipboard[2].id == "ctrlOptionV" && same(clipboard[2].record, 0x56, hotkey_mod::ctrl | hotkey_mod::alt));
    assert(clipboard[3].id == "optC" && same(clipboard[3].record, 0x43, hotkey_mod::alt));

    const auto& cleaner = HotkeyStore::presets_for(hotkey_action::cleaner);
    assert(cleaner.size() == 3);
    assert(cleaner[0].id == "optShiftK" && same(cleaner[0].record, 0x4B, hotkey_mod::alt | hotkey_mod::shift));
    assert(cleaner[1].id == "optShiftC" && same(cleaner[1].record, 0x43, hotkey_mod::alt | hotkey_mod::shift));
    assert(cleaner[2].id == "ctrlOptionK" && same(cleaner[2].record, 0x4B, hotkey_mod::ctrl | hotkey_mod::alt));

    const auto& ai = HotkeyStore::presets_for(hotkey_action::ai);
    assert(ai.size() == 3);
    assert(ai[0].id == "optSpace" && same(ai[0].record, 0x20, hotkey_mod::alt));
    assert(ai[1].id == "ctrlOptionSpace" && same(ai[1].record, 0x20, hotkey_mod::ctrl | hotkey_mod::alt));
    assert(ai[2].id == "cmdShiftSpace" && same(ai[2].record, 0x20, hotkey_mod::win | hotkey_mod::shift));

    assert(HotkeyStore::presets_for(hotkey_action::translate).empty());

    assert(HotkeyStore::default_preset_id(hotkey_action::toggle_language) == "optZ");
    assert(HotkeyStore::default_preset_id(hotkey_action::clipboard) == "optV");
    assert(HotkeyStore::default_preset_id(hotkey_action::cleaner) == "optShiftK");
    assert(HotkeyStore::default_preset_id(hotkey_action::ai) == "optSpace");

    // Defaults mirror SettingsModel/HotkeyManager: Alt+Z, Alt+V, Alt+Shift+K,
    // Alt+Space, Alt+T.
    const auto defaults = HotkeyStore::default_records();
    assert(defaults.size() == 5);
    assert(defaults[0].action == "toggleLanguage" && same(defaults[0], 0x5A, hotkey_mod::alt));
    assert(defaults[1].action == "clipboard" && same(defaults[1], 0x56, hotkey_mod::alt));
    assert(defaults[2].action == "cleaner" && same(defaults[2], 0x4B, hotkey_mod::alt | hotkey_mod::shift));
    assert(defaults[3].action == "ai" && same(defaults[3], 0x20, hotkey_mod::alt));
    assert(defaults[4].action == "translate" && same(defaults[4], 0x54, hotkey_mod::alt));

    assert(HotkeyStore::preset_id_for(hotkey_action::toggle_language, defaults[0]) == "optZ");
    assert(HotkeyStore::preset_id_for(hotkey_action::toggle_language, defaults[4]) == "custom");
    assert(!HotkeyStore::action_display_key(hotkey_action::ai).empty());
}

void test_conflicts() {
    const auto defaults = HotkeyStore::default_records();
    assert(HotkeyStore::detect_conflicts(defaults, true).empty());

    auto records = defaults;
    records[1] = records[0];
    const auto conflict = HotkeyStore::find_conflict(records, records[1], "clipboard", true);
    assert(conflict.has_value() && *conflict == "toggleLanguage");

    const auto pairs = HotkeyStore::detect_conflicts(records, true);
    assert(pairs.size() == 1);
    assert(pairs[0].first == 0 && pairs[0].second == 1);

    // A disabled cleaner never participates in conflict detection.
    auto cleaner_dup = defaults;
    cleaner_dup[1] = cleaner_dup[2];
    assert(!HotkeyStore::find_conflict(cleaner_dup, cleaner_dup[1], "clipboard", false).has_value());
    assert(HotkeyStore::find_conflict(cleaner_dup, cleaner_dup[1], "clipboard", true).has_value());
    assert(HotkeyStore::detect_conflicts(cleaner_dup, false).empty());

    // The edited action itself is excluded from matching.
    assert(!HotkeyStore::find_conflict(defaults, defaults[0], "toggleLanguage", true).has_value());

    // Modifier-only chord overlap.
    auto chord_dup = defaults;
    chord_dup.push_back({"extra", 0, hotkey_mod::ctrl | hotkey_mod::shift});
    chord_dup.push_back({"other", 0, hotkey_mod::ctrl | hotkey_mod::shift});
    assert(HotkeyStore::find_conflict(chord_dup, chord_dup.back(), "other", true).has_value());
}

void test_excluded_apps() {
    assert(excluded_apps::normalize("  Notepad.EXE ") == "notepad");
    assert(excluded_apps::normalize("NOTEPAD") == "notepad");
    assert(excluded_apps::normalize("C:\\Games\\League of Legends.exe") == "league of legends");
    assert(excluded_apps::normalize("D:/Apps/Code.exe") == "code");
    assert(excluded_apps::normalize("") == "");
    assert(excluded_apps::normalize("   ") == "");

    assert(excluded_apps::valid("notepad.exe"));
    assert(excluded_apps::valid("  VALORANT  "));
    assert(!excluded_apps::valid(""));
    assert(!excluded_apps::valid("   "));

    const auto deduped = excluded_apps::dedupe({"Notepad.exe", "notepad", "calc.exe", "", "  CALC "});
    assert(deduped.size() == 2);
    assert(deduped[0] == "notepad");
    assert(deduped[1] == "calc");

    auto apps = excluded_apps::with_added({}, "Notepad.exe");
    assert(apps.size() == 1 && apps[0] == "notepad");
    apps = excluded_apps::with_added(apps, "NOTEPAD");
    assert(apps.size() == 1);
    apps = excluded_apps::with_added(apps, "  ");
    assert(apps.size() == 1);
    apps = excluded_apps::with_added(apps, "valorant.exe");
    assert(apps.size() == 2 && apps[1] == "valorant");
}

void test_recorder() {
    ShortcutRecorderModel recorder;
    assert(!recorder.recording());

    recorder.begin();
    assert(recorder.recording() && !recorder.captured().has_value());
    assert(!recorder.on_key_down('Z', 0));
    assert(recorder.recording());
    recorder.cancel();
    assert(!recorder.recording());

    recorder.begin();
    assert(recorder.on_key_down(ShortcutRecorderModel::kVkEscape, 0));
    assert(!recorder.recording() && !recorder.captured().has_value());

    recorder.begin();
    assert(recorder.on_key_down(0x5A, hotkey_mod::alt));
    assert(!recorder.recording());
    assert(recorder.captured().has_value());
    assert(recorder.captured()->vk == 0x5A && recorder.captured()->modifiers == hotkey_mod::alt);

    recorder.begin();
    assert(recorder.on_key_down(0x70, 0));
    assert(recorder.captured().has_value() && recorder.captured()->vk == 0x70);

    // Modifier-only chord: hold Ctrl+Shift, release all.
    recorder.begin();
    assert(!recorder.on_modifiers_changed(hotkey_mod::shift));
    assert(recorder.live_modifiers() == hotkey_mod::shift);
    assert(!recorder.on_modifiers_changed(hotkey_mod::shift | hotkey_mod::ctrl));
    assert(recorder.peak_modifiers() == (hotkey_mod::shift | hotkey_mod::ctrl));
    assert(recorder.on_modifiers_changed(0));
    assert(!recorder.recording());
    assert(recorder.captured().has_value());
    assert(recorder.captured()->vk == 0);
    assert(recorder.captured()->modifiers == (hotkey_mod::shift | hotkey_mod::ctrl));

    // A single modifier pressed and released is not a chord.
    recorder.begin();
    assert(!recorder.on_modifiers_changed(hotkey_mod::alt));
    assert(!recorder.on_modifiers_changed(0));
    assert(recorder.recording() && !recorder.captured().has_value());

    // Key events outside a session are ignored.
    ShortcutRecorderModel idle;
    assert(!idle.on_key_down(0x5A, hotkey_mod::alt));
    assert(!idle.on_modifiers_changed(hotkey_mod::alt));
}

void test_store_round_trip() {
    const auto path = std::filesystem::temp_directory_path() / "skey-keyboard-settings-tests.json";
    std::filesystem::remove(path);
    SettingsStore store(path);

    SettingsModel model{};
    model.hotkeys = HotkeyStore::default_records();
    model.hotkeys[0] = {"toggleLanguage", 0, hotkey_mod::ctrl | hotkey_mod::shift};
    model.excluded_apps = excluded_apps::dedupe({"Notepad.exe", "notepad", "valorant"});
    assert(store.save(model));

    const auto loaded = store.load();
    assert(loaded.hotkeys.size() == 5);
    assert(loaded.hotkeys[0].action == "toggleLanguage");
    assert(loaded.hotkeys[0].vk == 0);
    assert(loaded.hotkeys[0].modifiers == (hotkey_mod::ctrl | hotkey_mod::shift));
    assert(HotkeyFormat::format(loaded.hotkeys[0]) == "Ctrl+Shift");
    assert(loaded.hotkeys[2].action == "cleaner");
    assert(HotkeyFormat::format(loaded.hotkeys[2]) == "Alt+Shift+K");
    assert(loaded.excluded_apps.size() == 2);
    assert(loaded.excluded_apps[0] == "notepad");
    assert(loaded.excluded_apps[1] == "valorant");

    std::filesystem::remove(path);
}

} // namespace

int main() {
    test_format_and_parse();
    test_presets_match_macos();
    test_conflicts();
    test_excluded_apps();
    test_recorder();
    test_store_round_trip();
    std::printf("KeyboardSettingsTests: all assertions passed\n");
    return 0;
}
