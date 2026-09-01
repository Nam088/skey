#include "SettingsBackup.h"

#include <cctype>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <sstream>
#include <utility>
#include <vector>

namespace {

bool is_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

std::size_t skip_space(const std::string& text, std::size_t at) {
    while (at < text.size() && is_space(text[at])) ++at;
    return at;
}

std::size_t find_value(const std::string& text, const std::string& key, const std::string& allowed_first) {
    const auto marker = "\"" + key + "\"";
    std::size_t at = 0;
    while ((at = text.find(marker, at)) != std::string::npos) {
        const auto colon = skip_space(text, at + marker.size());
        if (colon < text.size() && text[colon] == ':') {
            const auto value_at = skip_space(text, colon + 1);
            if (value_at < text.size() && allowed_first.find(text[value_at]) != std::string::npos) {
                return value_at;
            }
        }
        at += marker.size();
    }
    return std::string::npos;
}

bool read_quoted(const std::string& text, std::size_t& at, std::string& out) {
    if (at >= text.size() || text[at] != '"') return false;
    std::string result;
    ++at;
    while (at < text.size()) {
        const char c = text[at];
        if (c == '"') {
            ++at;
            out = std::move(result);
            return true;
        }
        if (c == '\\') {
            if (at + 1 >= text.size()) return false;
            switch (text[at + 1]) {
            case 'n': result += '\n'; break;
            case 't': result += '\t'; break;
            case 'r': result += '\r'; break;
            case '"': result += '"'; break;
            case '\\': result += '\\'; break;
            case '/': result += '/'; break;
            default: return false;
            }
            at += 2;
            continue;
        }
        result += c;
        ++at;
    }
    return false;
}

std::string value_for(const std::string& text, const std::string& key) {
    const auto at = find_value(text, key, "\"");
    if (at == std::string::npos) return {};
    auto cursor = at;
    std::string out;
    return read_quoted(text, cursor, out) ? out : std::string{};
}

bool bool_value_for(const std::string& text, const std::string& key, bool fallback) {
    const auto at = find_value(text, key, "tf");
    if (at == std::string::npos) return fallback;
    if (text.compare(at, 4, "true") == 0) return true;
    if (text.compare(at, 5, "false") == 0) return false;
    return fallback;
}

std::size_t int_value_for(const std::string& text, const std::string& key, std::size_t fallback) {
    const auto at = find_value(text, key, "0123456789");
    if (at == std::string::npos) return fallback;
    std::size_t value = 0;
    auto cursor = at;
    bool any = false;
    while (cursor < text.size() && std::isdigit(static_cast<unsigned char>(text[cursor]))) {
        value = value * 10 + static_cast<std::size_t>(text[cursor] - '0');
        any = true;
        ++cursor;
    }
    return any ? value : fallback;
}

bool read_object_block(const std::string& text, std::size_t at, std::string& inner) {
    if (at >= text.size() || text[at] != '{') return false;
    int depth = 0;
    bool in_string = false;
    for (std::size_t i = at; i < text.size(); ++i) {
        const char c = text[i];
        if (in_string) {
            if (c == '\\') {
                if (i + 1 >= text.size()) return false;
                ++i;
            } else if (c == '"') {
                in_string = false;
            }
        } else if (c == '"') {
            in_string = true;
        } else if (c == '{' || c == '[') {
            ++depth;
        } else if (c == '}' || c == ']') {
            --depth;
            if (depth == 0) {
                if (c != '}') return false;
                inner = text.substr(at + 1, i - at - 1);
                return true;
            }
        }
    }
    return false;
}

bool read_array_block(const std::string& text, std::size_t at, std::string& inner) {
    if (at >= text.size() || text[at] != '[') return false;
    int depth = 0;
    bool in_string = false;
    for (std::size_t i = at; i < text.size(); ++i) {
        const char c = text[i];
        if (in_string) {
            if (c == '\\') {
                if (i + 1 >= text.size()) return false;
                ++i;
            } else if (c == '"') {
                in_string = false;
            }
        } else if (c == '"') {
            in_string = true;
        } else if (c == '[' || c == '{') {
            ++depth;
        } else if (c == ']' || c == '}') {
            --depth;
            if (depth == 0) {
                if (c != ']') return false;
                inner = text.substr(at + 1, i - at - 1);
                return true;
            }
        }
    }
    return false;
}

bool string_array_for(const std::string& text, const std::string& key, std::vector<std::string>& items) {
    const auto at = find_value(text, key, "[");
    if (at == std::string::npos) return false;
    std::string inner;
    if (!read_array_block(text, at, inner)) return false;
    std::vector<std::string> parsed;
    auto cursor = skip_space(inner, 0);
    while (cursor < inner.size()) {
        std::string value;
        if (!read_quoted(inner, cursor, value)) return false;
        parsed.push_back(std::move(value));
        cursor = skip_space(inner, cursor);
        if (cursor < inner.size() && inner[cursor] == ',') {
            cursor = skip_space(inner, cursor + 1);
            continue;
        }
        break;
    }
    if (skip_space(inner, cursor) != inner.size()) return false;
    items = std::move(parsed);
    return true;
}

bool object_array_for(const std::string& text, const std::string& key, std::vector<std::string>& items) {
    const auto at = find_value(text, key, "[");
    if (at == std::string::npos) return false;
    std::string inner;
    if (!read_array_block(text, at, inner)) return false;
    std::vector<std::string> parsed;
    auto cursor = skip_space(inner, 0);
    while (cursor < inner.size()) {
        if (inner[cursor] != '{') return false;
        int depth = 0;
        bool in_string = false;
        bool closed = false;
        auto end = cursor;
        for (; end < inner.size(); ++end) {
            const char c = inner[end];
            if (in_string) {
                if (c == '\\') {
                    if (end + 1 >= inner.size()) return false;
                    ++end;
                } else if (c == '"') {
                    in_string = false;
                }
            } else if (c == '"') {
                in_string = true;
            } else if (c == '{') {
                ++depth;
            } else if (c == '}') {
                --depth;
                if (depth == 0) {
                    closed = true;
                    break;
                }
            }
        }
        if (!closed) return false;
        parsed.push_back(inner.substr(cursor, end - cursor + 1));
        cursor = skip_space(inner, end + 1);
        if (cursor < inner.size() && inner[cursor] == ',') {
            cursor = skip_space(inner, cursor + 1);
            continue;
        }
        break;
    }
    if (skip_space(inner, cursor) != inner.size()) return false;
    items = std::move(parsed);
    return true;
}

std::string json_escape(const std::string& value) {
    std::string out;
    out.reserve(value.size());
    for (const char c : value) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\t': out += "\\t"; break;
        case '\r': out += "\\r"; break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buffer[8];
                std::snprintf(buffer, sizeof(buffer), "\\u%04x", static_cast<unsigned>(static_cast<unsigned char>(c)));
                out += buffer;
            } else {
                out += c;
            }
        }
    }
    return out;
}

std::string bool_str(bool v) { return v ? "true" : "false"; }

std::string settings_to_json(const skey::windows::SettingsModel& s) {
    using skey::windows::ClipboardPinTo;
    using skey::windows::ClipboardPopupPosition;
    using skey::windows::ClipboardSortOrder;
    using skey::windows::HighlightMatchStyle;
    using skey::windows::InputMethod;
    using skey::windows::Locale;
    using skey::windows::ThemeMode;

    const auto locale = s.locale == Locale::en_us ? "en-US" : "vi-VN";
    const auto theme = s.theme == ThemeMode::dark ? "dark" : s.theme == ThemeMode::light ? "light" : "system";
    const auto method = s.input_method == InputMethod::vni ? "vni" : s.input_method == InputMethod::viqr ? "viqr" : s.input_method == InputMethod::simple_telex ? "simpleTelex" : "telex";
    const auto pin_to = s.clipboard_pin_to == ClipboardPinTo::bottom ? "bottom" : "top";
    const auto sort_order = s.clipboard_sort_order == ClipboardSortOrder::first_copied_at ? "firstCopiedAt"
        : s.clipboard_sort_order == ClipboardSortOrder::number_of_copies ? "numberOfCopies" : "lastCopiedAt";
    const auto highlight = s.clipboard_highlight_match == HighlightMatchStyle::bold ? "bold"
        : s.clipboard_highlight_match == HighlightMatchStyle::italic ? "italic"
        : s.clipboard_highlight_match == HighlightMatchStyle::underline ? "underline" : "color";
    const auto popup_position = s.clipboard_popup_position == ClipboardPopupPosition::status_item ? "statusItem" : "cursor";

    std::ostringstream output;
    output << "{\n"
        << "    \"schemaVersion\": " << s.schema_version << ",\n"
        << "    \"locale\": \"" << locale << "\",\n"
        << "    \"theme\": \"" << theme << "\",\n"
        << "    \"inputMethod\": \"" << method << "\",\n"
        << "    \"charset\": \"" << json_escape(s.charset) << "\",\n"
        << "    \"isVietnamese\": " << bool_str(s.is_vietnamese) << ",\n"
        << "    \"appExclusionEnabled\": " << bool_str(s.app_exclusion_enabled) << ",\n"
        << "    \"excludedApps\": [";
    for (std::size_t i = 0; i < s.excluded_apps.size(); ++i) {
        output << (i == 0 ? "" : ", ") << '"' << json_escape(s.excluded_apps[i]) << '"';
    }
    output << "],\n"
        << "    \"spellCheck\": " << bool_str(s.spell_check) << ",\n"
        << "    \"freeMarking\": " << bool_str(s.free_marking) << ",\n"
        << "    \"modernStyle\": " << bool_str(s.modern_style) << ",\n"
        << "    \"swallowedKeyRestore\": " << bool_str(s.swallowed_key_restore) << ",\n"
        << "    \"quickTelex\": " << bool_str(s.quick_telex) << ",\n"
        << "    \"quickStartConsonant\": " << bool_str(s.quick_start_consonant) << ",\n"
        << "    \"quickEndConsonant\": " << bool_str(s.quick_end_consonant) << ",\n"
        << "    \"upperCaseFirstChar\": " << bool_str(s.upper_case_first_char) << ",\n"
        << "    \"allowConsonantZfwj\": " << bool_str(s.allow_consonant_zfwj) << ",\n"
        << "    \"smartAppSwitch\": " << bool_str(s.smart_app_switch) << ",\n"
        << "    \"launchAtLogin\": " << bool_str(s.launch_at_login) << ",\n"
        << "    \"checkUpdates\": " << bool_str(s.check_updates) << ",\n"
        << "    \"debugMode\": " << bool_str(s.debug_mode) << ",\n"
        << "    \"clipboardEnabled\": " << bool_str(s.clipboard_enabled) << ",\n"
        << "    \"clipboardMaxItems\": " << s.clipboard_max_items << ",\n"
        << "    \"clipboardAutoPaste\": " << bool_str(s.clipboard_auto_paste) << ",\n"
        << "    \"clipboardPastePlainText\": " << bool_str(s.clipboard_paste_plain_text) << ",\n"
        << "    \"clipboardSaveText\": " << bool_str(s.clipboard_save_text) << ",\n"
        << "    \"clipboardSaveImages\": " << bool_str(s.clipboard_save_images) << ",\n"
        << "    \"clipboardSearchMode\": \"" << json_escape(s.clipboard_search_mode) << "\",\n"
        << "    \"clipboardShowAppIcons\": " << bool_str(s.clipboard_show_app_icons) << ",\n"
        << "    \"clipboardShowHexColorSwatch\": " << bool_str(s.clipboard_show_hex_color_swatch) << ",\n"
        << "    \"clipboardShowFooter\": " << bool_str(s.clipboard_show_footer) << ",\n"
        << "    \"clipboardShowTitle\": " << bool_str(s.clipboard_show_title) << ",\n"
        << "    \"clipboardSuppressClearAlert\": " << bool_str(s.clipboard_suppress_clear_alert) << ",\n"
        << "    \"clipboardOpenPreviewAuto\": " << bool_str(s.clipboard_open_preview_auto) << ",\n"
        << "    \"clipboardPreviewDelayMs\": " << s.clipboard_preview_delay_ms << ",\n"
        << "    \"clipboardImageThumbHeight\": " << s.clipboard_image_thumb_height << ",\n"
        << "    \"clipboardPinTo\": \"" << pin_to << "\",\n"
        << "    \"clipboardSortOrder\": \"" << sort_order << "\",\n"
        << "    \"clipboardHighlightMatch\": \"" << highlight << "\",\n"
        << "    \"clipboardPopupPosition\": \"" << popup_position << "\",\n"
        << "    \"cleanerEnabled\": " << bool_str(s.cleaner_enabled) << ",\n"
        << "    \"hotkeys\": [";
    for (std::size_t i = 0; i < s.hotkeys.size(); ++i) {
        const auto& record = s.hotkeys[i];
        output << (i == 0 ? "" : ",")
            << "\n      {\"action\": \"" << json_escape(record.action)
            << "\", \"vk\": " << record.vk
            << ", \"modifiers\": " << record.modifiers << "}";
    }
    output << (s.hotkeys.empty() ? "" : "\n    ") << "],\n"
        << "    \"translatorTargetLanguage\": \"" << json_escape(s.translator_target_language) << "\",\n"
        << "    \"translatorAutoDetect\": " << bool_str(s.translator_auto_detect) << ",\n"
        << "    \"translatorPreferredEngine\": \"" << json_escape(s.translator_preferred_engine) << "\",\n"
        << "    \"translatorEngines\": [";
    for (std::size_t i = 0; i < s.translator_engines.size(); ++i) {
        const auto& engine = s.translator_engines[i];
        output << (i == 0 ? "" : ",")
            << "\n      {\"provider\": \"" << json_escape(engine.provider)
            << "\", \"enabled\": " << bool_str(engine.enabled)
            << ", \"apiKey\": \"" << json_escape(engine.api_key) << "\"}";
    }
    output << (s.translator_engines.empty() ? "" : "\n    ") << "],\n"
        << "    \"macroEnabled\": " << bool_str(s.macro_enabled) << ",\n"
        << "    \"macroAutoCaps\": " << bool_str(s.macro_auto_caps) << ",\n"
        << "    \"macroInEnglishMode\": " << bool_str(s.macro_in_english_mode) << ",\n"
        << "    \"useImeForBrowsers\": " << bool_str(s.use_ime_for_browsers) << "\n"
        << "  }";
    return output.str();
}

void parse_settings(const std::string& text, skey::windows::SettingsModel& r) {
    using namespace skey::windows;

    r.schema_version = static_cast<std::uint32_t>(int_value_for(text, "schemaVersion", r.schema_version));
    const auto locale = value_for(text, "locale");
    const auto theme = value_for(text, "theme");
    const auto method = value_for(text, "inputMethod");
    if (locale == "en-US") r.locale = Locale::en_us;
    if (theme == "light") r.theme = ThemeMode::light;
    else if (theme == "dark") r.theme = ThemeMode::dark;
    if (method == "vni") r.input_method = InputMethod::vni;
    else if (method == "viqr") r.input_method = InputMethod::viqr;
    else if (method == "simpleTelex") r.input_method = InputMethod::simple_telex;
    const auto charset = value_for(text, "charset");
    if (!charset.empty()) r.charset = charset;

    r.is_vietnamese = bool_value_for(text, "isVietnamese", true);
    r.app_exclusion_enabled = bool_value_for(text, "appExclusionEnabled", true);
    std::vector<std::string> excluded_apps;
    if (string_array_for(text, "excludedApps", excluded_apps)) {
        r.excluded_apps = std::move(excluded_apps);
    }

    r.spell_check = bool_value_for(text, "spellCheck", true);
    r.free_marking = bool_value_for(text, "freeMarking", true);
    r.modern_style = bool_value_for(text, "modernStyle", false);
    r.swallowed_key_restore = bool_value_for(text, "swallowedKeyRestore", true);
    r.quick_telex = bool_value_for(text, "quickTelex", false);
    r.quick_start_consonant = bool_value_for(text, "quickStartConsonant", false);
    r.quick_end_consonant = bool_value_for(text, "quickEndConsonant", false);
    r.upper_case_first_char = bool_value_for(text, "upperCaseFirstChar", false);
    r.allow_consonant_zfwj = bool_value_for(text, "allowConsonantZfwj", false);
    r.smart_app_switch = bool_value_for(text, "smartAppSwitch", false);
    r.launch_at_login = bool_value_for(text, "launchAtLogin", false);
    r.check_updates = bool_value_for(text, "checkUpdates", true);
    r.debug_mode = bool_value_for(text, "debugMode", false);
    r.clipboard_enabled = bool_value_for(text, "clipboardEnabled", true);
    r.clipboard_max_items = int_value_for(text, "clipboardMaxItems", 100);
    r.clipboard_auto_paste = bool_value_for(text, "clipboardAutoPaste", true);
    r.clipboard_paste_plain_text = bool_value_for(text, "clipboardPastePlainText", false);
    r.clipboard_save_text = bool_value_for(text, "clipboardSaveText", true);
    r.clipboard_save_images = bool_value_for(text, "clipboardSaveImages", false);

    const auto search_mode = value_for(text, "clipboardSearchMode");
    if (!search_mode.empty()) r.clipboard_search_mode = search_mode;
    r.clipboard_show_app_icons = bool_value_for(text, "clipboardShowAppIcons", true);
    r.clipboard_show_hex_color_swatch = bool_value_for(text, "clipboardShowHexColorSwatch", true);
    r.clipboard_show_footer = bool_value_for(text, "clipboardShowFooter", true);
    r.clipboard_show_title = bool_value_for(text, "clipboardShowTitle", false);
    r.clipboard_suppress_clear_alert = bool_value_for(text, "clipboardSuppressClearAlert", false);
    r.clipboard_open_preview_auto = bool_value_for(text, "clipboardOpenPreviewAuto", true);
    r.clipboard_preview_delay_ms = int_value_for(text, "clipboardPreviewDelayMs", 250);
    r.clipboard_image_thumb_height = int_value_for(text, "clipboardImageThumbHeight", 40);
    if (value_for(text, "clipboardPinTo") == "bottom") r.clipboard_pin_to = ClipboardPinTo::bottom;
    const auto sort_order = value_for(text, "clipboardSortOrder");
    if (sort_order == "firstCopiedAt") r.clipboard_sort_order = ClipboardSortOrder::first_copied_at;
    else if (sort_order == "numberOfCopies") r.clipboard_sort_order = ClipboardSortOrder::number_of_copies;
    const auto highlight = value_for(text, "clipboardHighlightMatch");
    if (highlight == "bold") r.clipboard_highlight_match = HighlightMatchStyle::bold;
    else if (highlight == "italic") r.clipboard_highlight_match = HighlightMatchStyle::italic;
    else if (highlight == "underline") r.clipboard_highlight_match = HighlightMatchStyle::underline;
    if (value_for(text, "clipboardPopupPosition") == "statusItem") {
        r.clipboard_popup_position = ClipboardPopupPosition::status_item;
    }

    r.macro_enabled = bool_value_for(text, "macroEnabled", true);
    r.macro_auto_caps = bool_value_for(text, "macroAutoCaps", true);
    r.macro_in_english_mode = bool_value_for(text, "macroInEnglishMode", false);
    r.use_ime_for_browsers = bool_value_for(text, "useImeForBrowsers", true);

    r.cleaner_enabled = bool_value_for(text, "cleanerEnabled", true);
    std::vector<std::string> hotkey_objects;
    if (object_array_for(text, "hotkeys", hotkey_objects)) {
        std::vector<HotkeyRecord> parsed;
        parsed.reserve(hotkey_objects.size());
        for (const auto& object : hotkey_objects) {
            HotkeyRecord record{};
            record.action = value_for(object, "action");
            record.vk = static_cast<unsigned>(int_value_for(object, "vk", 0));
            record.modifiers = static_cast<unsigned>(int_value_for(object, "modifiers", 0));
            if (!record.action.empty()) parsed.push_back(std::move(record));
        }
        r.hotkeys = std::move(parsed);
    }

    const auto target_language = value_for(text, "translatorTargetLanguage");
    if (!target_language.empty()) r.translator_target_language = target_language;
    r.translator_auto_detect = bool_value_for(text, "translatorAutoDetect", true);
    const auto preferred_engine = value_for(text, "translatorPreferredEngine");
    if (!preferred_engine.empty()) r.translator_preferred_engine = preferred_engine;
    std::vector<std::string> engine_objects;
    if (object_array_for(text, "translatorEngines", engine_objects)) {
        std::vector<TranslatorEngine> parsed;
        parsed.reserve(engine_objects.size());
        for (const auto& object : engine_objects) {
            TranslatorEngine engine{};
            engine.provider = value_for(object, "provider");
            engine.enabled = bool_value_for(object, "enabled", true);
            engine.api_key = value_for(object, "apiKey");
            if (!engine.provider.empty()) parsed.push_back(std::move(engine));
        }
        r.translator_engines = std::move(parsed);
    }
}

bool read_file(const std::filesystem::path& path, std::string& out) {
    std::ifstream input(path, std::ios::binary);
    if (!input.good()) return false;
    std::ostringstream buffer;
    buffer << input.rdbuf();
    out = buffer.str();
    return true;
}

} // namespace

namespace skey::windows {

bool SettingsBackup::export_to_file(const SettingsModel& model,
                                    const std::filesystem::path& destination,
                                    const std::filesystem::path& macros_json_path) {
    std::error_code error;
    if (!destination.parent_path().empty()) {
        std::filesystem::create_directories(destination.parent_path(), error);
        if (error) return false;
    }
    std::ofstream output(destination, std::ios::trunc);
    if (!output.good()) return false;

    output << "{\n"
           << "  \"app\": \"SKey\",\n"
           << "  \"backupFormatVersion\": 1,\n";

    char exported_at[32] = {};
    const std::time_t now = std::time(nullptr);
#ifdef _WIN32
    std::tm utc_storage{};
    gmtime_s(&utc_storage, &now);
    const std::tm* utc = &utc_storage;
#else
    const std::tm* utc = std::gmtime(&now);
#endif
    if (utc != nullptr && std::strftime(exported_at, sizeof(exported_at), "%Y-%m-%dT%H:%M:%SZ", utc) != 0) {
        output << "  \"exportedAt\": \"" << exported_at << "\",\n";
    }

    const auto macros_path = macros_json_path.empty() ? destination.parent_path() / "macros.json" : macros_json_path;
    std::string macros_content;
    if (std::filesystem::is_regular_file(macros_path, error) && !error && read_file(macros_path, macros_content)) {
        std::string escaped;
        escaped.reserve(macros_content.size());
        for (const char c : macros_content) {
            if (c == '"') escaped += "\\\"";
            else if (c == '\\') escaped += "\\\\";
            else if (static_cast<unsigned char>(c) >= 0x20) escaped += c;
        }
        output << "  \"macros\": \"" << escaped << "\",\n";
    }

    output << "  \"settings\": " << settings_to_json(model) << "\n"
           << "}\n";
    return output.good();
}

bool SettingsBackup::import_from_file(const std::filesystem::path& source,
                                      SettingsModel& out,
                                      std::string* macros_json_out) {
    std::string text;
    if (!read_file(source, text)) return false;
    if (value_for(text, "app") != "SKey") return false;

    const auto settings_at = find_value(text, "settings", "{");
    if (settings_at == std::string::npos) return false;
    std::string settings_text;
    if (!read_object_block(text, settings_at, settings_text)) return false;

    if (find_value(settings_text, "schemaVersion", "0123456789") == std::string::npos) return false;
    const auto schema = int_value_for(settings_text, "schemaVersion", 0);
    if (schema == 0 || schema > SettingsModel{}.schema_version) return false;

    SettingsModel model{};
    parse_settings(settings_text, model);

    if (macros_json_out != nullptr) {
        macros_json_out->clear();
        if (find_value(text, "macros", "\"") != std::string::npos) {
            *macros_json_out = value_for(text, "macros");
        }
    }

    out = std::move(model);
    return true;
}

bool SettingsBackup::factory_reset(const SettingsStore& store) {
    return store.reset();
}

std::string SettingsBackup::default_backup_filename() {
    char buffer[48] = {};
    const std::time_t now = std::time(nullptr);
#ifdef _WIN32
    std::tm local_storage{};
    localtime_s(&local_storage, &now);
    const std::tm* local = &local_storage;
#else
    const std::tm* local = std::localtime(&now);
#endif
    if (local == nullptr || std::strftime(buffer, sizeof(buffer), "skey_backup_%Y%m%d_%H%M%S.json", local) == 0) {
        return "skey_backup.json";
    }
    return buffer;
}

} // namespace skey::windows
