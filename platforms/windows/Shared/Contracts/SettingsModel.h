#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace skey::windows {

enum class ThemeMode : std::uint8_t { system, light, dark };
enum class Locale : std::uint8_t { vi_vn, en_us };
enum class InputMethod : std::uint8_t { telex, vni, viqr, simple_telex };

struct SettingsModel final {
    std::uint32_t schema_version{2};
    Locale locale{Locale::vi_vn};
    ThemeMode theme{ThemeMode::system};
    InputMethod input_method{InputMethod::telex};
    std::string charset{"unicode"};
    bool is_vietnamese{true};
    std::vector<std::string> excluded_apps;

    bool spell_check{true};
    bool free_marking{true};
    bool modern_style{false};
    bool swallowed_key_restore{true};
    bool quick_telex{false};
    bool quick_start_consonant{false};
    bool quick_end_consonant{false};
    bool upper_case_first_char{false};
    bool allow_consonant_zfwj{false};
    bool smart_app_switch{false};

    bool launch_at_login{false};
    bool check_updates{true};
    bool debug_mode{false};

    bool clipboard_enabled{true};
    std::size_t clipboard_max_items{100};
    bool clipboard_auto_paste{true};
    bool clipboard_paste_plain_text{false};
    bool clipboard_save_text{true};
    bool clipboard_save_images{false};

    bool macro_enabled{true};
    bool macro_auto_caps{true};
    bool macro_in_english_mode{false};
};

} // namespace skey::windows
