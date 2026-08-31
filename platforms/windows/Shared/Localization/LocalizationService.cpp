#include "LocalizationService.h"

#include <array>

namespace skey::windows {
namespace {
struct Entry { std::string_view key; std::string_view vi; std::string_view en; };
constexpr std::array<Entry, 18> kEntries{{
    {"menu.language.vietnamese", "Tiếng Việt", "Vietnamese"},
    {"menu.language.english", "Tiếng Anh", "English"},
    {"settings.general.title", "Chung", "General"},
    {"settings.keyboard.title", "Bàn phím", "Keyboard"},
    {"settings.shortcuts.title", "Phím tắt", "Shortcuts"},
    {"settings.appearance.title", "Giao diện", "Appearance"},
    {"settings.theme.system", "Theo hệ thống", "System"},
    {"settings.theme.light", "Sáng", "Light"},
    {"settings.theme.dark", "Tối", "Dark"},
    {"settings.clipboard.title", "Clipboard", "Clipboard"},
    {"settings.translator.title", "Dịch", "Translator"},
    {"settings.cleaner.title", "Dọn bàn phím", "Keyboard cleaner"},
    {"settings.about.title", "Giới thiệu", "About"},
    {"settings.general.enable", "Bật bộ gõ tiếng Việt", "Enable Vietnamese input"},
    {"settings.general.startup", "Khởi động cùng hệ thống", "Launch at startup"},
    {"settings.keyboard.input_method", "Kiểu gõ", "Input method"},
    {"settings.keyboard.spell_check", "Tự động sửa lỗi", "Spell check"},
    {"settings.clipboard.enable", "Bật lịch sử clipboard", "Enable clipboard history"},
}};
constexpr std::string_view kMissing = "[missing translation]";
}

std::string_view LocalizationService::text(std::string_view key) const {
    for (const auto& entry : kEntries) {
        if (entry.key == key) return locale_ == Locale::vi_vn ? entry.vi : entry.en;
    }
    return kMissing;
}
}
