#pragma once

#include "../Contracts/SettingsModel.h"

namespace skey::windows {

enum class ResolvedTheme : unsigned char { light, dark };

class ThemeResolver final {
public:
    static ResolvedTheme resolve(ThemeMode requested, bool system_dark) {
        if (requested == ThemeMode::dark) return ResolvedTheme::dark;
        if (requested == ThemeMode::light) return ResolvedTheme::light;
        return system_dark ? ResolvedTheme::dark : ResolvedTheme::light;
    }
};

} // namespace skey::windows
