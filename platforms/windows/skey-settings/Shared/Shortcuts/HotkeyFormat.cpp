#include "HotkeyFormat.h"

#include <array>
#include <cctype>
#include <string>
#include <utility>
#include <vector>

namespace skey::windows {

namespace {

constexpr unsigned kVkBackspace = 0x08;
constexpr unsigned kVkTab = 0x09;
constexpr unsigned kVkEnter = 0x0D;
constexpr unsigned kVkEscape = 0x1B;
constexpr unsigned kVkSpace = 0x20;
constexpr unsigned kVkPageUp = 0x21;
constexpr unsigned kVkPageDown = 0x22;
constexpr unsigned kVkEnd = 0x23;
constexpr unsigned kVkHome = 0x24;
constexpr unsigned kVkLeft = 0x25;
constexpr unsigned kVkUp = 0x26;
constexpr unsigned kVkRight = 0x27;
constexpr unsigned kVkDown = 0x28;
constexpr unsigned kVkPrintScreen = 0x2C;
constexpr unsigned kVkInsert = 0x2D;
constexpr unsigned kVkDelete = 0x2E;
constexpr unsigned kVkDigit0 = 0x30;
constexpr unsigned kVkLetterA = 0x41;
constexpr unsigned kVkLetterZ = 0x5A;
constexpr unsigned kVkNumpad0 = 0x60;
constexpr unsigned kVkNumpad9 = 0x69;
constexpr unsigned kVkF1 = 0x70;
constexpr unsigned kVkF24 = 0x87;
constexpr unsigned kVkScrollLock = 0x91;

bool is_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

std::string to_lower(std::string_view text) {
    std::string out(text);
    for (auto& c : out) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return out;
}

std::string_view trim(std::string_view text) {
    while (!text.empty() && is_space(text.front())) text.remove_prefix(1);
    while (!text.empty() && is_space(text.back())) text.remove_suffix(1);
    return text;
}

bool try_modifier(std::string_view token, unsigned& mods) {
    const auto name = to_lower(token);
    if (name == "shift") { mods |= hotkey_mod::shift; return true; }
    if (name == "ctrl" || name == "control") { mods |= hotkey_mod::ctrl; return true; }
    if (name == "alt" || name == "option") { mods |= hotkey_mod::alt; return true; }
    if (name == "win" || name == "windows" || name == "cmd" || name == "command" || name == "super") {
        mods |= hotkey_mod::win;
        return true;
    }
    return false;
}

constexpr std::array<std::pair<std::string_view, unsigned>, 20> kNamedKeys = {{
    {"space", kVkSpace},
    {"enter", kVkEnter},
    {"return", kVkEnter},
    {"tab", kVkTab},
    {"escape", kVkEscape},
    {"esc", kVkEscape},
    {"backspace", kVkBackspace},
    {"back", kVkBackspace},
    {"delete", kVkDelete},
    {"del", kVkDelete},
    {"insert", kVkInsert},
    {"ins", kVkInsert},
    {"printscreen", kVkPrintScreen},
    {"scrolllock", kVkScrollLock},
    {"home", kVkHome},
    {"end", kVkEnd},
    {"pageup", kVkPageUp},
    {"pgup", kVkPageUp},
    {"pagedown", kVkPageDown},
    {"pgdn", kVkPageDown},
}};

constexpr std::array<std::pair<std::string_view, unsigned>, 8> kSymbolKeys = {{
    {";", 0xBA}, {"=", 0xBB}, {",", 0xBC}, {"-", 0xBD},
    {".", 0xBE}, {"/", 0xBF}, {"`", 0xC0}, {"[", 0xDB},
}};

constexpr std::array<std::pair<std::string_view, unsigned>, 3> kSymbolKeys2 = {{
    {"\\", 0xDC}, {"]", 0xDD}, {"'", 0xDE},
}};

} // namespace

namespace {

std::optional<unsigned> parse_fallback_token(const std::string& name) {
    if (name.size() < 6 || name.compare(0, 4, "key(") != 0 || name.back() != ')') return std::nullopt;
    unsigned value = 0;
    bool any = false;
    for (std::size_t i = 4; i + 1 < name.size(); ++i) {
        const char c = name[i];
        if (c < '0' || c > '9') return std::nullopt;
        value = value * 10 + static_cast<unsigned>(c - '0');
        any = true;
    }
    return any ? std::optional<unsigned>{value} : std::nullopt;
}

} // namespace

std::string HotkeyFormat::key_name(unsigned vk) {
    if (vk >= kVkLetterA && vk <= kVkLetterZ) {
        return std::string(1, static_cast<char>('A' + (vk - kVkLetterA)));
    }
    if (vk >= kVkDigit0 && vk <= kVkDigit0 + 9) {
        return std::string(1, static_cast<char>('0' + (vk - kVkDigit0)));
    }
    if (vk >= kVkF1 && vk <= kVkF24) return "F" + std::to_string(vk - kVkF1 + 1);
    if (vk >= kVkNumpad0 && vk <= kVkNumpad9) return "Num " + std::to_string(vk - kVkNumpad0);
    switch (vk) {
    case kVkSpace: return "Space";
    case kVkEnter: return "Enter";
    case kVkTab: return "Tab";
    case kVkEscape: return "Escape";
    case kVkBackspace: return "Backspace";
    case kVkDelete: return "Delete";
    case kVkInsert: return "Insert";
    case kVkPrintScreen: return "PrintScreen";
    case kVkScrollLock: return "ScrollLock";
    case kVkLeft: return "Left";
    case kVkRight: return "Right";
    case kVkUp: return "Up";
    case kVkDown: return "Down";
    case kVkHome: return "Home";
    case kVkEnd: return "End";
    case kVkPageUp: return "PageUp";
    case kVkPageDown: return "PageDown";
    case 0x6A: return "Num *";
    case 0x6B: return "Num +";
    case 0x6C: return "Num Enter";
    case 0x6D: return "Num -";
    case 0x6E: return "Num .";
    case 0x6F: return "Num /";
    case 0xBA: return ";";
    case 0xBB: return "=";
    case 0xBC: return ",";
    case 0xBD: return "-";
    case 0xBE: return ".";
    case 0xBF: return "/";
    case 0xC0: return "`";
    case 0xDB: return "[";
    case 0xDC: return "\\";
    case 0xDD: return "]";
    case 0xDE: return "'";
    default: return "Key(" + std::to_string(vk) + ")";
    }
}

std::optional<unsigned> HotkeyFormat::vk_for_name(std::string_view name) {
    const auto lower = to_lower(trim(name));
    if (lower.empty()) return std::nullopt;
    if (lower.size() == 1) {
        const char c = lower[0];
        if (c >= 'a' && c <= 'z') return kVkLetterA + static_cast<unsigned>(c - 'a');
        if (c >= '0' && c <= '9') return kVkDigit0 + static_cast<unsigned>(c - '0');
    }
    if (lower.size() >= 2 && lower[0] == 'f') {
        bool all_digits = true;
        unsigned number = 0;
        for (std::size_t i = 1; i < lower.size(); ++i) {
            if (lower[i] < '0' || lower[i] > '9') { all_digits = false; break; }
            number = number * 10 + static_cast<unsigned>(lower[i] - '0');
        }
        if (all_digits && number >= 1 && number <= 24) return kVkF1 + number - 1;
    }
    if (lower.compare(0, 4, "num ") == 0) {
        const auto rest = lower.substr(4);
        if (rest.size() == 1 && rest[0] >= '0' && rest[0] <= '9') {
            return kVkNumpad0 + static_cast<unsigned>(rest[0] - '0');
        }
        if (rest == "*") return 0x6Au;
        if (rest == "+") return 0x6Bu;
        if (rest == "enter") return 0x6Cu;
        if (rest == "-") return 0x6Du;
        if (rest == ".") return 0x6Eu;
        if (rest == "/") return 0x6Fu;
        return std::nullopt;
    }
    if (lower == "left") return kVkLeft;
    if (lower == "right") return kVkRight;
    if (lower == "up") return kVkUp;
    if (lower == "down") return kVkDown;
    for (const auto& [key, vk] : kNamedKeys) {
        if (lower == key) return vk;
    }
    for (const auto& [key, vk] : kSymbolKeys) {
        if (lower == key) return vk;
    }
    for (const auto& [key, vk] : kSymbolKeys2) {
        if (lower == key) return vk;
    }
    return parse_fallback_token(lower);
}

std::string HotkeyFormat::format(const HotkeyRecord& record) {
    if (record.vk == 0 && record.modifiers == 0) return {};
    std::string out;
    const auto append = [&out](std::string_view part) {
        if (!out.empty()) out += '+';
        out += part;
    };
    if (record.modifiers & hotkey_mod::ctrl) append("Ctrl");
    if (record.modifiers & hotkey_mod::alt) append("Alt");
    if (record.modifiers & hotkey_mod::shift) append("Shift");
    if (record.modifiers & hotkey_mod::win) append("Win");
    if (record.vk != 0) append(key_name(record.vk));
    return out;
}

std::optional<HotkeyRecord> HotkeyFormat::parse(std::string_view text) {
    std::vector<std::string_view> tokens;
    std::size_t start = 0;
    while (true) {
        const auto plus = text.find('+', start);
        const auto end = plus == std::string_view::npos ? text.size() : plus;
        tokens.push_back(trim(text.substr(start, end - start)));
        if (plus == std::string_view::npos) break;
        start = plus + 1;
    }
    // "Num +" display names embed the separator; fold the trailing piece back.
    if (tokens.size() >= 2 && tokens.back().empty()
        && to_lower(tokens[tokens.size() - 2]) == "num") {
        tokens.pop_back();
        tokens.back() = "Num +";
    }
    unsigned mods = 0;
    unsigned vk = 0;
    bool has_key = false;
    for (const auto raw : tokens) {
        if (raw.empty()) return std::nullopt;
        if (try_modifier(raw, mods)) continue;
        if (has_key) return std::nullopt;
        const auto code = vk_for_name(raw);
        if (!code) return std::nullopt;
        vk = *code;
        has_key = true;
    }
    if (!has_key && mods == 0) return std::nullopt;
    return HotkeyRecord{{}, vk, mods};
}

} // namespace skey::windows
