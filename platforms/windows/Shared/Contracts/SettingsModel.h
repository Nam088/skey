#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace skey::windows {

enum class ThemeMode : std::uint8_t { system, light, dark };
enum class Locale : std::uint8_t { vi_vn, en_us };
enum class InputMethod : std::uint8_t { telex, vni, viqr, simple_telex };
enum class ClipboardPinTo : std::uint8_t { top, bottom };
enum class ClipboardSortOrder : std::uint8_t { last_copied_at, first_copied_at, number_of_copies };
enum class HighlightMatchStyle : std::uint8_t { color, bold, italic, underline };
enum class ClipboardPopupPosition : std::uint8_t { cursor, status_item };

// Modifier bits mirror skey-tray ModifierBits: shift=1, ctrl=2, alt=4.
struct HotkeyRecord final {
    std::string action;
    unsigned vk{0};
    unsigned modifiers{0};
};

struct TranslatorEngine final {
    std::string provider;
    bool enabled{true};
    std::string api_key;
};

struct SettingsModel final {
    std::uint32_t schema_version{2};
    Locale locale{Locale::vi_vn};
    ThemeMode theme{ThemeMode::system};
    InputMethod input_method{InputMethod::telex};
    std::string charset{"unicode"};
    bool is_vietnamese{true};
    bool app_exclusion_enabled{true};
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
    std::string clipboard_search_mode{"Fuzzy"};
    bool clipboard_show_app_icons{true};
    bool clipboard_show_hex_color_swatch{true};
    bool clipboard_show_footer{true};
    bool clipboard_show_title{false};
    bool clipboard_suppress_clear_alert{false};
    bool clipboard_open_preview_auto{true};
    std::size_t clipboard_preview_delay_ms{250};
    std::size_t clipboard_image_thumb_height{40};
    ClipboardPinTo clipboard_pin_to{ClipboardPinTo::top};
    ClipboardSortOrder clipboard_sort_order{ClipboardSortOrder::last_copied_at};
    HighlightMatchStyle clipboard_highlight_match{HighlightMatchStyle::color};
    ClipboardPopupPosition clipboard_popup_position{ClipboardPopupPosition::cursor};

    bool macro_enabled{true};
    bool macro_auto_caps{true};
    bool macro_in_english_mode{false};

    bool cleaner_enabled{true};
    std::vector<HotkeyRecord> hotkeys{
        {"toggleLanguage", 0x5Au, 4u},
        {"clipboard", 0x56u, 4u},
        {"cleaner", 0x4Bu, 5u},
        {"ai", 0x20u, 4u},
        {"translate", 0x54u, 4u},
    };

    std::string translator_target_language{"vi"};
    bool translator_auto_detect{true};
    std::string translator_preferred_engine{"google"};
    std::vector<TranslatorEngine> translator_engines{
        {"google", true, {}},
        {"apple", true, {}},
        {"gemini", true, {}},
        {"deepl", true, {}},
        {"groq", true, {}},
    };
};

} // namespace skey::windows
