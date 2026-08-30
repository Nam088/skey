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
    void reset() { settings_ = {}; localization_.set_locale(settings_.locale); }

    std::string_view general_title() const { return localization_.text("settings.general.title"); }
    std::string_view keyboard_title() const { return localization_.text("settings.keyboard.title"); }
    std::string_view shortcuts_title() const { return localization_.text("settings.shortcuts.title"); }
    std::string_view appearance_title() const { return localization_.text("settings.appearance.title"); }

    // Stable names for XAML bindings; the native projection can convert UTF-8
    // to hstring at the boundary without coupling the model to WinRT.
    std::string_view GeneralTitle() const { return general_title(); }
    std::string_view KeyboardTitle() const { return keyboard_title(); }
    std::string_view ShortcutsTitle() const { return shortcuts_title(); }
    std::string_view AppearanceTitle() const { return appearance_title(); }

private:
    SettingsModel settings_{};
    LocalizationService localization_;
};

} // namespace skey::windows
