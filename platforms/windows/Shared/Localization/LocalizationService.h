#pragma once

#include "../Contracts/SettingsModel.h"

#include <string_view>

namespace skey::windows {

class LocalizationService final {
public:
    explicit LocalizationService(Locale locale = Locale::vi_vn) : locale_(locale) {}

    // Process-wide instance; TrayRuntime keeps its locale in sync with the
    // settings file so tray UI (menu, HUDs, balloons) can translate.
    static LocalizationService& shared();

    void set_locale(Locale locale) { locale_ = locale; }
    Locale locale() const { return locale_; }
    std::string_view text(std::string_view key) const;

private:
    Locale locale_;
};

} // namespace skey::windows
