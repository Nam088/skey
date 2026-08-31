#pragma once

#include "../../Shared/Contracts/SettingsModel.h"
#include "../../Shared/Localization/LocalizationService.h"
#include "../../Shared/Settings/SettingsStore.h"

#include <algorithm>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace skey::windows {

class SettingsViewModel final {
public:
    SettingsViewModel() : localization_(settings_.locale) {}

    explicit SettingsViewModel(SettingsStore store)
        : store_(std::move(store)), settings_(store_->load()), localization_(settings_.locale) {}

    const SettingsModel& settings() const { return settings_; }
    bool has_store() const { return store_.has_value(); }
    void save() {
        if (store_) store_->save(settings_);
    }

    void apply(const SettingsModel& model) {
        settings_ = model;
        localization_.set_locale(settings_.locale);
        save();
    }

    void factory_reset() {
        settings_ = {};
        localization_.set_locale(settings_.locale);
        if (store_) store_->reset();
    }

    void set_theme(ThemeMode theme) { settings_.theme = theme; save(); }
    void set_locale(Locale locale) { settings_.locale = locale; localization_.set_locale(locale); save(); }
    void set_input_method(InputMethod method) { settings_.input_method = method; save(); }
    void set_charset(std::string charset) { settings_.charset = std::move(charset); save(); }
    void set_vietnamese(bool v) { settings_.is_vietnamese = v; save(); }

    void set_spell_check(bool v) { settings_.spell_check = v; save(); }
    void set_free_marking(bool v) { settings_.free_marking = v; save(); }
    void set_modern_style(bool v) { settings_.modern_style = v; save(); }
    void set_swallowed_key_restore(bool v) { settings_.swallowed_key_restore = v; save(); }
    void set_quick_telex(bool v) { settings_.quick_telex = v; save(); }
    void set_quick_start_consonant(bool v) { settings_.quick_start_consonant = v; save(); }
    void set_quick_end_consonant(bool v) { settings_.quick_end_consonant = v; save(); }
    void set_upper_case_first_char(bool v) { settings_.upper_case_first_char = v; save(); }
    void set_allow_consonant_zfwj(bool v) { settings_.allow_consonant_zfwj = v; save(); }
    void set_smart_app_switch(bool v) { settings_.smart_app_switch = v; save(); }

    void set_launch_at_login(bool v) { settings_.launch_at_login = v; save(); }
    void set_check_updates(bool v) { settings_.check_updates = v; save(); }
    void set_debug_mode(bool v) { settings_.debug_mode = v; save(); }

    void set_app_exclusion_enabled(bool v) { settings_.app_exclusion_enabled = v; save(); }

    void set_excluded_apps(std::vector<std::string> apps) { settings_.excluded_apps = std::move(apps); save(); }

    void add_excluded_app(const std::string& app) {
        if (app.empty()) return;
        if (std::find(settings_.excluded_apps.begin(), settings_.excluded_apps.end(), app)
            != settings_.excluded_apps.end()) {
            return;
        }
        settings_.excluded_apps.push_back(app);
        save();
    }

    void remove_excluded_app(const std::string& app) {
        auto& apps = settings_.excluded_apps;
        const auto before = apps.size();
        apps.erase(std::remove(apps.begin(), apps.end(), app), apps.end());
        if (apps.size() != before) save();
    }

    void set_clipboard_enabled(bool v) { settings_.clipboard_enabled = v; save(); }
    void set_clipboard_max_items(std::size_t v) { settings_.clipboard_max_items = v; save(); }
    void set_clipboard_auto_paste(bool v) { settings_.clipboard_auto_paste = v; save(); }
    void set_clipboard_paste_plain_text(bool v) { settings_.clipboard_paste_plain_text = v; save(); }
    void set_clipboard_save_text(bool v) { settings_.clipboard_save_text = v; save(); }
    void set_clipboard_save_images(bool v) { settings_.clipboard_save_images = v; save(); }
    void set_clipboard_search_mode(std::string v) { settings_.clipboard_search_mode = std::move(v); save(); }
    void set_clipboard_show_app_icons(bool v) { settings_.clipboard_show_app_icons = v; save(); }
    void set_clipboard_show_hex_color_swatch(bool v) { settings_.clipboard_show_hex_color_swatch = v; save(); }
    void set_clipboard_show_footer(bool v) { settings_.clipboard_show_footer = v; save(); }
    void set_clipboard_show_title(bool v) { settings_.clipboard_show_title = v; save(); }
    void set_clipboard_suppress_clear_alert(bool v) { settings_.clipboard_suppress_clear_alert = v; save(); }
    void set_clipboard_open_preview_auto(bool v) { settings_.clipboard_open_preview_auto = v; save(); }
    void set_clipboard_preview_delay_ms(std::size_t v) { settings_.clipboard_preview_delay_ms = v; save(); }
    void set_clipboard_image_thumb_height(std::size_t v) { settings_.clipboard_image_thumb_height = v; save(); }
    void set_clipboard_pin_to(ClipboardPinTo v) { settings_.clipboard_pin_to = v; save(); }
    void set_clipboard_sort_order(ClipboardSortOrder v) { settings_.clipboard_sort_order = v; save(); }
    void set_clipboard_highlight_match(HighlightMatchStyle v) { settings_.clipboard_highlight_match = v; save(); }
    void set_clipboard_popup_position(ClipboardPopupPosition v) { settings_.clipboard_popup_position = v; save(); }

    void set_macro_enabled(bool v) { settings_.macro_enabled = v; save(); }
    void set_macro_auto_caps(bool v) { settings_.macro_auto_caps = v; save(); }
    void set_macro_in_english_mode(bool v) { settings_.macro_in_english_mode = v; save(); }

    void set_cleaner_enabled(bool v) { settings_.cleaner_enabled = v; save(); }

    void set_hotkeys(std::vector<HotkeyRecord> hotkeys) { settings_.hotkeys = std::move(hotkeys); save(); }

    void set_hotkey(const HotkeyRecord& hotkey) {
        for (auto& record : settings_.hotkeys) {
            if (record.action == hotkey.action) {
                record = hotkey;
                save();
                return;
            }
        }
        settings_.hotkeys.push_back(hotkey);
        save();
    }

    const HotkeyRecord* hotkey_for(const std::string& action) const {
        for (const auto& record : settings_.hotkeys) {
            if (record.action == action) return &record;
        }
        return nullptr;
    }

    void set_translator_target_language(std::string v) { settings_.translator_target_language = std::move(v); save(); }
    void set_translator_auto_detect(bool v) { settings_.translator_auto_detect = v; save(); }
    void set_translator_preferred_engine(std::string v) { settings_.translator_preferred_engine = std::move(v); save(); }

    void set_translator_api_key(const std::string& provider, std::string key) {
        for (auto& engine : settings_.translator_engines) {
            if (engine.provider == provider) {
                engine.api_key = std::move(key);
                save();
                return;
            }
        }
    }

    void set_translator_engine_enabled(const std::string& provider, bool enabled) {
        for (auto& engine : settings_.translator_engines) {
            if (engine.provider == provider) {
                engine.enabled = enabled;
                save();
                return;
            }
        }
    }

    void reset() { settings_ = {}; localization_.set_locale(settings_.locale); save(); }

    std::string_view general_title() const { return localization_.text("settings.general.title"); }
    std::string_view keyboard_title() const { return localization_.text("settings.keyboard.title"); }
    std::string_view clipboard_title() const { return localization_.text("settings.clipboard.title"); }
    std::string_view shortcuts_title() const { return localization_.text("settings.shortcuts.title"); }
    std::string_view snippets_title() const { return localization_.text("settings.snippets.title"); }
    std::string_view tools_title() const { return localization_.text("settings.tools.title"); }
    std::string_view about_title() const { return localization_.text("settings.about.title"); }
    std::string_view appearance_title() const { return localization_.text("settings.appearance.title"); }

    std::string_view GeneralTitle() const { return general_title(); }
    std::string_view KeyboardTitle() const { return keyboard_title(); }
    std::string_view ClipboardTitle() const { return clipboard_title(); }
    std::string_view ShortcutsTitle() const { return shortcuts_title(); }
    std::string_view SnippetsTitle() const { return snippets_title(); }
    std::string_view ToolsTitle() const { return tools_title(); }
    std::string_view AboutTitle() const { return about_title(); }
    std::string_view AppearanceTitle() const { return appearance_title(); }

private:
    std::optional<SettingsStore> store_;
    SettingsModel settings_{};
    LocalizationService localization_;
};

} // namespace skey::windows
