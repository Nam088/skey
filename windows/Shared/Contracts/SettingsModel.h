#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace skey::windows {

enum class ThemeMode : std::uint8_t { system, light, dark };
enum class Locale : std::uint8_t { vi_vn, en_us };
enum class InputMethod : std::uint8_t { telex, vni, viqr, simple_telex };

struct SettingsModel final {
    std::uint32_t schema_version{1};
    Locale locale{Locale::vi_vn};
    ThemeMode theme{ThemeMode::system};
    InputMethod input_method{InputMethod::telex};
    std::string charset{"unicode"};
    bool is_vietnamese{true};
    std::vector<std::string> excluded_apps;
};

} // namespace skey::windows
