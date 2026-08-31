#pragma once

#include "../../Shared/Contracts/SettingsModel.h"
#include "../../Shared/Localization/LocalizationService.h"
#include <string_view>

namespace skey::windows {

class SettingsViewModel final {
public:
    SettingsViewModel() : localization_(settings_.locale) {}

    const SettingsModel& settings() const { return settings_; }

    void set_theme(ThemeMode theme) { settings_.theme = theme; }
    void set_locale(Locale locale) { settings_.locale = locale; localization_.set_locale(locale); }
    void set_input_method(InputMethod method) { settings_.input_method = method; }
    void set_charset(std::string charset) { settings_.charset = std::move(charset); }
    void set_vietnamese(bool v) { settings_.is_vietnamese = v; }

    void set_spell_check(bool v) { settings_.spell_check = v; }
    void set_free_marking(bool v) { settings_.free_marking = v; }
    void set_modern_style(bool v) { settings_.modern_style = v; }
    void set_swallowed_key_restore(bool v) { settings_.swallowed_key_restore = v; }
    void set_quick_telex(bool v) { settings_.quick_telex = v; }
    void set_quick_start_consonant(bool v) { settings_.quick_start_consonant = v; }
    void set_quick_end_consonant(bool v) { settings_.quick_end_consonant = v; }
    void set_upper_case_first_char(bool v) { settings_.upper_case_first_char = v; }
    void set_allow_consonant_zfwj(bool v) { settings_.allow_consonant_zfwj = v; }
    void set_smart_app_switch(bool v) { settings_.smart_app_switch = v; }

    void set_launch_at_login(bool v) { settings_.launch_at_login = v; }
    void set_check_updates(bool v) { settings_.check_updates = v; }
    void set_debug_mode(bool v) { settings_.debug_mode = v; }

    void set_clipboard_enabled(bool v) { settings_.clipboard_enabled = v; }
    void set_clipboard_max_items(std::size_t v) { settings_.clipboard_max_items = v; }
    void set_clipboard_auto_paste(bool v) { settings_.clipboard_auto_paste = v; }
    void set_clipboard_paste_plain_text(bool v) { settings_.clipboard_paste_plain_text = v; }
    void set_clipboard_save_text(bool v) { settings_.clipboard_save_text = v; }
    void set_clipboard_save_images(bool v) { settings_.clipboard_save_images = v; }

    void set_macro_enabled(bool v) { settings_.macro_enabled = v; }
    void set_macro_auto_caps(bool v) { settings_.macro_auto_caps = v; }
    void set_macro_in_english_mode(bool v) { settings_.macro_in_english_mode = v; }

    void reset() { settings_ = {}; localization_.set_locale(settings_.locale); }

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
    SettingsModel settings_{};
    LocalizationService localization_;
};

} // namespace skey::windows
