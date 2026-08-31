#include "../Shared/Contracts/SettingsModel.h"
#include "../Shared/Settings/SettingsStore.h"
#include "../skey-settings/Shared/Settings/Backup/SettingsBackup.h"

#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>

using namespace skey::windows;

namespace {

SettingsModel make_full_model() {
    SettingsModel m{};
    m.schema_version = 2;
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
    m.use_ime_for_browsers = false;
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
    assert(a.use_ime_for_browsers == b.use_ime_for_browsers);
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

void write_text(const std::filesystem::path& path, const std::string& content) {
    std::ofstream output(path, std::ios::trunc);
    output << content;
}

} // namespace

int main() {
    const auto dir = std::filesystem::temp_directory_path() / "skey-backup-tests";
    std::error_code cleanup_error;
    std::filesystem::remove_all(dir, cleanup_error);
    std::filesystem::create_directories(dir, cleanup_error);
    const auto backup_path = dir / "skey_backup_test.json";
    const auto settings_path = dir / "settings.json";

    // Round-trip: export then import preserves every field.
    const auto full = make_full_model();
    assert(SettingsBackup::export_to_file(full, backup_path));
    assert(std::filesystem::exists(backup_path));
    SettingsModel imported{};
    std::string imported_macros = "sentinel";
    assert(SettingsBackup::import_from_file(backup_path, imported, &imported_macros));
    assert_models_equal(imported, full);
    assert(imported_macros.empty());

    // Round-trip of the untouched defaults as well.
    const auto defaults = SettingsModel{};
    assert(SettingsBackup::export_to_file(defaults, backup_path));
    imported = make_full_model();
    assert(SettingsBackup::import_from_file(backup_path, imported));
    assert_models_equal(imported, defaults);

    // macros.json next to the backup file is embedded and restored verbatim.
    const auto macros_path = dir / "macros.json";
    const std::string macros_content = "{\"items\":[{\"trigger\":\"vn\",\"expansion\":\"Việt Nam\\u00e9\"}]}";
    write_text(macros_path, macros_content);
    assert(SettingsBackup::export_to_file(full, backup_path));
    imported_macros.clear();
    assert(SettingsBackup::import_from_file(backup_path, imported, &imported_macros));
    assert_models_equal(imported, full);
    assert(imported_macros == macros_content);

    // Corrupt/truncated backup -> false, settings untouched.
    {
        SettingsModel sentinel = make_full_model();
        const auto corrupt_path = dir / "corrupt.json";
        write_text(corrupt_path, "{\"app\": \"SKey\", \"settings\": {\"schemaVersion\": 2, \"locale\": \"en-US\", \"hotkeys\": [{\"action\": \"ai\", \"vk\":");
        assert(!SettingsBackup::import_from_file(corrupt_path, sentinel));
        assert_models_equal(sentinel, full);
        write_text(corrupt_path, "this is not json at all");
        assert(!SettingsBackup::import_from_file(corrupt_path, sentinel));
        assert_models_equal(sentinel, full);
    }

    // Foreign file (different app marker) -> false.
    {
        SettingsModel sentinel = make_full_model();
        const auto foreign_path = dir / "foreign.json";
        write_text(foreign_path, "{\"app\": \"OtherApp\", \"settings\": {\"schemaVersion\": 2}}");
        assert(!SettingsBackup::import_from_file(foreign_path, sentinel));
        assert_models_equal(sentinel, full);
    }

    // Missing or future schema version -> false.
    {
        SettingsModel sentinel = make_full_model();
        const auto schema_path = dir / "schema.json";
        write_text(schema_path, "{\"app\": \"SKey\", \"settings\": {\"locale\": \"en-US\"}}");
        assert(!SettingsBackup::import_from_file(schema_path, sentinel));
        write_text(schema_path, "{\"app\": \"SKey\", \"settings\": {\"schemaVersion\": 99, \"locale\": \"en-US\"}}");
        assert(!SettingsBackup::import_from_file(schema_path, sentinel));
        write_text(schema_path, "{\"app\": \"SKey\", \"settings\": {\"schemaVersion\": 0}}");
        assert(!SettingsBackup::import_from_file(schema_path, sentinel));
        assert_models_equal(sentinel, full);
    }

    // Older schema version imports fine; unknown enum strings keep defaults.
    {
        const auto legacy_path = dir / "legacy.json";
        write_text(legacy_path,
                   "{\"app\": \"SKey\", \"settings\": {\"schemaVersion\": 1, \"locale\": \"en-US\", "
                   "\"clipboardMaxItems\": 42, \"clipboardPinTo\": \"sideways\", \"clipboardSortOrder\": \"weird\"}}");
        SettingsModel legacy{};
        assert(SettingsBackup::import_from_file(legacy_path, legacy));
        assert(legacy.schema_version == 1);
        assert(legacy.locale == Locale::en_us);
        assert(legacy.clipboard_max_items == 42);
        assert(legacy.clipboard_pin_to == ClipboardPinTo::top);
        assert(legacy.clipboard_sort_order == ClipboardSortOrder::last_copied_at);
        assert(legacy.hotkeys.size() == 5);
        assert(legacy.translator_engines.size() == 5);
    }

    // Missing file -> false.
    {
        SettingsModel sentinel{};
        assert(!SettingsBackup::import_from_file(dir / "missing.json", sentinel));
    }

    // Factory reset deletes the settings file and restores defaults.
    SettingsStore store(settings_path);
    assert(store.save(full));
    assert(std::filesystem::exists(settings_path));
    assert(SettingsBackup::factory_reset(store));
    assert(!std::filesystem::exists(settings_path));
    const auto reset_loaded = store.load();
    assert_models_equal(reset_loaded, SettingsModel{});

    // Default filename mirrors the macOS skey_backup_<timestamp>.json pattern.
    const auto name = SettingsBackup::default_backup_filename();
    assert(name.rfind("skey_backup_", 0) == 0);
    assert(name.size() > std::string("skey_backup_").size() + 5);
    assert(name.substr(name.size() - 5) == ".json");

    std::filesystem::remove_all(dir, cleanup_error);
    std::cout << "SETTINGS_BACKUP_OK\n";
    return 0;
}
