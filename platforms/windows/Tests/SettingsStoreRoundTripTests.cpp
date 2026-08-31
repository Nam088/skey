#include "../Shared/Contracts/SettingsModel.h"
#include "../Shared/Settings/SettingsStore.h"

#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>

using namespace skey::windows;

namespace {

SettingsModel make_full_model() {
    SettingsModel m{};
    m.schema_version = 3;
    m.locale = Locale::en_us;
    m.theme = ThemeMode::dark;
    m.input_method = InputMethod::simple_telex;
    m.charset = "tcvn3";
    m.is_vietnamese = false;
    m.app_exclusion_enabled = false;
    m.excluded_apps = {"Zalo.exe", "Game Launcher.exe", "C:\\apps\\quoted\"name.exe"};
    m.spell_check = false;
    m.free_marking = false;
    m.modern_style = true;
    m.swallowed_key_restore = false;
    m.quick_telex = true;
    m.quick_start_consonant = true;
    m.quick_end_consonant = true;
    m.upper_case_first_char = true;
    m.allow_consonant_zfwj = true;
    m.smart_app_switch = true;
    m.launch_at_login = true;
    m.check_updates = false;
    m.debug_mode = true;
    m.clipboard_enabled = false;
    m.clipboard_max_items = 250;
    m.clipboard_auto_paste = false;
    m.clipboard_paste_plain_text = true;
    m.clipboard_save_text = false;
    m.clipboard_save_images = true;
    m.clipboard_search_mode = "Exact";
    m.clipboard_show_app_icons = false;
    m.clipboard_show_hex_color_swatch = false;
    m.clipboard_show_footer = false;
    m.clipboard_show_title = true;
    m.clipboard_suppress_clear_alert = true;
    m.clipboard_open_preview_auto = false;
    m.clipboard_preview_delay_ms = 500;
    m.clipboard_image_thumb_height = 64;
    m.clipboard_pin_to = ClipboardPinTo::bottom;
    m.clipboard_sort_order = ClipboardSortOrder::number_of_copies;
    m.clipboard_highlight_match = HighlightMatchStyle::underline;
    m.clipboard_popup_position = ClipboardPopupPosition::status_item;
    m.macro_enabled = false;
    m.macro_auto_caps = false;
    m.macro_in_english_mode = true;
    m.cleaner_enabled = false;
    m.hotkeys = {
        {"toggleLanguage", 0x5Au, 4u},
        {"clipboard", 0x43u, 5u},
        {"cleaner", 0x4Bu, 3u},
        {"ai", 0x20u, 6u},
        {"translate", 0x54u, 2u},
    };
    m.translator_target_language = "en";
    m.translator_auto_detect = false;
    m.translator_preferred_engine = "deepl";
    m.translator_engines = {
        {"deepl", true, "key-123"},
        {"groq", false, {}},
    };
    return m;
}

void assert_models_equal(const SettingsModel& a, const SettingsModel& b) {
    assert(a.schema_version == b.schema_version);
    assert(a.locale == b.locale);
    assert(a.theme == b.theme);
    assert(a.input_method == b.input_method);
    assert(a.charset == b.charset);
    assert(a.is_vietnamese == b.is_vietnamese);
    assert(a.app_exclusion_enabled == b.app_exclusion_enabled);
    assert(a.excluded_apps == b.excluded_apps);
    assert(a.spell_check == b.spell_check);
    assert(a.free_marking == b.free_marking);
    assert(a.modern_style == b.modern_style);
    assert(a.swallowed_key_restore == b.swallowed_key_restore);
    assert(a.quick_telex == b.quick_telex);
    assert(a.quick_start_consonant == b.quick_start_consonant);
    assert(a.quick_end_consonant == b.quick_end_consonant);
    assert(a.upper_case_first_char == b.upper_case_first_char);
    assert(a.allow_consonant_zfwj == b.allow_consonant_zfwj);
    assert(a.smart_app_switch == b.smart_app_switch);
    assert(a.launch_at_login == b.launch_at_login);
    assert(a.check_updates == b.check_updates);
    assert(a.debug_mode == b.debug_mode);
    assert(a.clipboard_enabled == b.clipboard_enabled);
    assert(a.clipboard_max_items == b.clipboard_max_items);
    assert(a.clipboard_auto_paste == b.clipboard_auto_paste);
    assert(a.clipboard_paste_plain_text == b.clipboard_paste_plain_text);
    assert(a.clipboard_save_text == b.clipboard_save_text);
    assert(a.clipboard_save_images == b.clipboard_save_images);
    assert(a.clipboard_search_mode == b.clipboard_search_mode);
    assert(a.clipboard_show_app_icons == b.clipboard_show_app_icons);
    assert(a.clipboard_show_hex_color_swatch == b.clipboard_show_hex_color_swatch);
    assert(a.clipboard_show_footer == b.clipboard_show_footer);
    assert(a.clipboard_show_title == b.clipboard_show_title);
    assert(a.clipboard_suppress_clear_alert == b.clipboard_suppress_clear_alert);
    assert(a.clipboard_open_preview_auto == b.clipboard_open_preview_auto);
    assert(a.clipboard_preview_delay_ms == b.clipboard_preview_delay_ms);
    assert(a.clipboard_image_thumb_height == b.clipboard_image_thumb_height);
    assert(a.clipboard_pin_to == b.clipboard_pin_to);
    assert(a.clipboard_sort_order == b.clipboard_sort_order);
    assert(a.clipboard_highlight_match == b.clipboard_highlight_match);
    assert(a.clipboard_popup_position == b.clipboard_popup_position);
    assert(a.macro_enabled == b.macro_enabled);
    assert(a.macro_auto_caps == b.macro_auto_caps);
    assert(a.macro_in_english_mode == b.macro_in_english_mode);
    assert(a.cleaner_enabled == b.cleaner_enabled);
    assert(a.hotkeys.size() == b.hotkeys.size());
    for (std::size_t i = 0; i < a.hotkeys.size(); ++i) {
        assert(a.hotkeys[i].action == b.hotkeys[i].action);
        assert(a.hotkeys[i].vk == b.hotkeys[i].vk);
        assert(a.hotkeys[i].modifiers == b.hotkeys[i].modifiers);
    }
    assert(a.translator_target_language == b.translator_target_language);
    assert(a.translator_auto_detect == b.translator_auto_detect);
    assert(a.translator_preferred_engine == b.translator_preferred_engine);
    assert(a.translator_engines.size() == b.translator_engines.size());
    for (std::size_t i = 0; i < a.translator_engines.size(); ++i) {
        assert(a.translator_engines[i].provider == b.translator_engines[i].provider);
        assert(a.translator_engines[i].enabled == b.translator_engines[i].enabled);
        assert(a.translator_engines[i].api_key == b.translator_engines[i].api_key);
    }
}

} // namespace

int main() {
    const auto path = std::filesystem::temp_directory_path() / "skey-settings-roundtrip-test.json";
    std::error_code cleanup_error;
    std::filesystem::remove(path, cleanup_error);
    SettingsStore store(path);

    // Missing file -> defaults, including the five default hotkeys.
    assert(!std::filesystem::exists(path));
    const auto defaults = store.load();
    assert(defaults.locale == Locale::vi_vn && defaults.theme == ThemeMode::system);
    assert(defaults.input_method == InputMethod::telex && defaults.charset == "unicode");
    assert(defaults.app_exclusion_enabled && defaults.cleaner_enabled);
    assert(defaults.excluded_apps.empty());
    assert(defaults.hotkeys.size() == 5);
    assert(defaults.hotkeys[0].action == "toggleLanguage");
    assert(defaults.hotkeys[0].vk == 0x5A && defaults.hotkeys[0].modifiers == 4);
    assert(defaults.hotkeys[1].action == "clipboard");
    assert(defaults.hotkeys[1].vk == 0x56 && defaults.hotkeys[1].modifiers == 4);
    assert(defaults.hotkeys[2].action == "cleaner");
    assert(defaults.hotkeys[2].vk == 0x4B && defaults.hotkeys[2].modifiers == 5);
    assert(defaults.hotkeys[3].action == "ai");
    assert(defaults.hotkeys[3].vk == 0x20 && defaults.hotkeys[3].modifiers == 4);
    assert(defaults.hotkeys[4].action == "translate");
    assert(defaults.hotkeys[4].vk == 0x54 && defaults.hotkeys[4].modifiers == 4);
    assert(defaults.clipboard_search_mode == "Fuzzy");
    assert(defaults.clipboard_show_app_icons && defaults.clipboard_show_hex_color_swatch);
    assert(defaults.clipboard_show_footer && !defaults.clipboard_show_title);
    assert(!defaults.clipboard_suppress_clear_alert && defaults.clipboard_open_preview_auto);
    assert(defaults.clipboard_preview_delay_ms == 250 && defaults.clipboard_image_thumb_height == 40);
    assert(defaults.clipboard_pin_to == ClipboardPinTo::top);
    assert(defaults.clipboard_sort_order == ClipboardSortOrder::last_copied_at);
    assert(defaults.clipboard_highlight_match == HighlightMatchStyle::color);
    assert(defaults.clipboard_popup_position == ClipboardPopupPosition::cursor);
    assert(defaults.translator_target_language == "vi" && defaults.translator_auto_detect);
    assert(defaults.translator_preferred_engine == "google");
    assert(defaults.translator_engines.size() == 5);
    assert(defaults.translator_engines[0].provider == "google" && defaults.translator_engines[0].enabled);
    assert(defaults.translator_engines[0].api_key.empty());

    // Full round-trip of every field.
    const auto full = make_full_model();
    assert(store.save(full));
    assert(std::filesystem::exists(path));
    assert_models_equal(store.load(), full);

    // Legacy file without the new keys -> new fields keep defaults.
    {
        std::ofstream legacy(path, std::ios::trunc);
        legacy << "{\n  \"locale\": \"en-US\",\n  \"clipboardMaxItems\": 42\n}\n";
    }
    const auto legacy = store.load();
    assert(legacy.locale == Locale::en_us && legacy.clipboard_max_items == 42);
    assert(legacy.hotkeys.size() == 5);
    assert(legacy.excluded_apps.empty());
    assert(legacy.translator_engines.size() == 5);
    assert(legacy.app_exclusion_enabled && legacy.cleaner_enabled);

    // Corrupt file -> defaults, never crash.
    {
        std::ofstream corrupt(path, std::ios::trunc);
        corrupt << "{\"locale\": \"invalid\", \"theme\": 42, \"hotkeys\": [{\"action\": \"ai\", \"vk\":";
    }
    const auto recovered = store.load();
    assert(recovered.locale == Locale::vi_vn && recovered.theme == ThemeMode::system);
    assert(recovered.hotkeys.size() == 5);
    assert(recovered.excluded_apps.empty());
    {
        std::ofstream corrupt(path, std::ios::trunc);
        corrupt << "this is not json at all";
    }
    const auto garbage = store.load();
    assert(garbage.locale == Locale::vi_vn && garbage.clipboard_max_items == 100);

    // reset() removes the file.
    assert(store.save(full));
    assert(std::filesystem::exists(path));
    assert(store.reset());
    assert(!std::filesystem::exists(path));

    std::cout << "SETTINGS_STORE_ROUND_TRIP_OK\n";
    return 0;
}
