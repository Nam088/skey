#include "LocalizationService.h"

#include <array>

namespace skey::windows {
namespace {
struct Entry { std::string_view key; std::string_view vi; std::string_view en; };
constexpr std::array<Entry, 33> kEntries{{
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
    {"tray.menu.switch_english", "Chuyển sang tiếng Anh", "Switch to English"},
    {"tray.menu.switch_vietnamese", "Chuyển sang tiếng Việt", "Switch to Vietnamese"},
    {"tray.menu.settings", "Cài đặt...", "Settings..."},
    {"tray.menu.quit", "Thoát", "Quit"},
    {"tray.update.title", "Đã có bản cập nhật SKey", "SKey update available"},
    {"tray.update.message_prefix", "Phiên bản ", "Version "},
    {"tray.update.message_suffix", " đã sẵn sàng — bấm để tải.", " is ready — click to download."},
    {"hud.clipboard.title", "SKey Clipboard", "SKey Clipboard"},
    {"hud.translate.title", "SKey Dịch", "SKey Translate"},
    {"hud.translate.button", "Dịch", "Translate"},
    {"hud.translate.busy", "Đang dịch…", "Translating…"},
    {"hud.translate.failed", "Dịch thất bại", "translation failed"},
    {"cleaner.badge.locked", "Đã khóa", "Locked"},
    {"cleaner.esc.hint", "Giữ Esc 2 giây để mở khóa — bấm để mở khóa", "Hold Esc for 2 seconds to unlock — click to unlock"},
    {"cleaner.esc.holding", "Tiếp tục giữ Esc…", "Keep holding Esc…"},
}};
constexpr std::string_view kMissing = "[missing translation]";
}

LocalizationService& LocalizationService::shared() {
    static LocalizationService instance;
    return instance;
}

std::string_view LocalizationService::text(std::string_view key) const {
    for (const auto& entry : kEntries) {
        if (entry.key == key) return locale_ == Locale::vi_vn ? entry.vi : entry.en;
    }
    return kMissing;
}
}
