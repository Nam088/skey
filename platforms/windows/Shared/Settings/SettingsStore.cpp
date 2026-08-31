#include "SettingsStore.h"

#include <fstream>
#include <sstream>

namespace {
std::string value_for(const std::string& text, const std::string& key) {
    const auto marker = "\"" + key + "\"";
    const auto at = text.find(marker);
    if (at == std::string::npos) return {};
    const auto colon = text.find(':', at + marker.size());
    const auto first = text.find('"', colon + 1);
    if (colon == std::string::npos || first == std::string::npos) return {};
    const auto last = text.find('"', first + 1);
    return last == std::string::npos ? std::string{} : text.substr(first + 1, last - first - 1);
}

bool bool_value_for(const std::string& text, const std::string& key, bool default_value) {
    const auto marker = "\"" + key + "\"";
    const auto at = text.find(marker);
    if (at == std::string::npos) return default_value;
    const auto colon = text.find(':', at + marker.size());
    if (colon == std::string::npos) return default_value;
    const auto rest = text.substr(colon + 1, 20);
    if (rest.find("true") != std::string::npos) return true;
    if (rest.find("false") != std::string::npos) return false;
    return default_value;
}

std::size_t int_value_for(const std::string& text, const std::string& key, std::size_t default_value) {
    const auto marker = "\"" + key + "\"";
    const auto at = text.find(marker);
    if (at == std::string::npos) return default_value;
    const auto colon = text.find(':', at + marker.size());
    if (colon == std::string::npos) return default_value;
    const auto rest = text.substr(colon + 1, 20);
    try { return std::stoull(rest); } catch (...) { return default_value; }
}

std::string bool_str(bool v) { return v ? "true" : "false"; }
} // namespace

namespace skey::windows {

SettingsStore::SettingsStore(std::filesystem::path path) : path_(std::move(path)) {}

SettingsModel SettingsStore::load() const {
    std::ifstream input(path_);
    if (!input.good()) return {};
    std::ostringstream buffer;
    buffer << input.rdbuf();
    const auto text = buffer.str();
    SettingsModel r{};

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
    r.macro_enabled = bool_value_for(text, "macroEnabled", true);
    r.macro_auto_caps = bool_value_for(text, "macroAutoCaps", true);
    r.macro_in_english_mode = bool_value_for(text, "macroInEnglishMode", false);

    return r;
}

bool SettingsStore::save(const SettingsModel& s) const {
    std::error_code error;
    if (!path_.parent_path().empty()) {
        std::filesystem::create_directories(path_.parent_path(), error);
        if (error) return false;
    }
    std::ofstream output(path_, std::ios::trunc);
    if (!output.good()) return false;

    const auto locale = s.locale == Locale::en_us ? "en-US" : "vi-VN";
    const auto theme = s.theme == ThemeMode::dark ? "dark" : s.theme == ThemeMode::light ? "light" : "system";
    const auto method = s.input_method == InputMethod::vni ? "vni" : s.input_method == InputMethod::viqr ? "viqr" : s.input_method == InputMethod::simple_telex ? "simpleTelex" : "telex";

    output << "{\n"
        << "  \"schemaVersion\": " << s.schema_version << ",\n"
        << "  \"locale\": \"" << locale << "\",\n"
        << "  \"theme\": \"" << theme << "\",\n"
        << "  \"inputMethod\": \"" << method << "\",\n"
        << "  \"charset\": \"" << s.charset << "\",\n"
        << "  \"isVietnamese\": " << bool_str(s.is_vietnamese) << ",\n"
        << "  \"spellCheck\": " << bool_str(s.spell_check) << ",\n"
        << "  \"freeMarking\": " << bool_str(s.free_marking) << ",\n"
        << "  \"modernStyle\": " << bool_str(s.modern_style) << ",\n"
        << "  \"swallowedKeyRestore\": " << bool_str(s.swallowed_key_restore) << ",\n"
        << "  \"quickTelex\": " << bool_str(s.quick_telex) << ",\n"
        << "  \"quickStartConsonant\": " << bool_str(s.quick_start_consonant) << ",\n"
        << "  \"quickEndConsonant\": " << bool_str(s.quick_end_consonant) << ",\n"
        << "  \"upperCaseFirstChar\": " << bool_str(s.upper_case_first_char) << ",\n"
        << "  \"allowConsonantZfwj\": " << bool_str(s.allow_consonant_zfwj) << ",\n"
        << "  \"smartAppSwitch\": " << bool_str(s.smart_app_switch) << ",\n"
        << "  \"launchAtLogin\": " << bool_str(s.launch_at_login) << ",\n"
        << "  \"checkUpdates\": " << bool_str(s.check_updates) << ",\n"
        << "  \"debugMode\": " << bool_str(s.debug_mode) << ",\n"
        << "  \"clipboardEnabled\": " << bool_str(s.clipboard_enabled) << ",\n"
        << "  \"clipboardMaxItems\": " << s.clipboard_max_items << ",\n"
        << "  \"clipboardAutoPaste\": " << bool_str(s.clipboard_auto_paste) << ",\n"
        << "  \"clipboardPastePlainText\": " << bool_str(s.clipboard_paste_plain_text) << ",\n"
        << "  \"clipboardSaveText\": " << bool_str(s.clipboard_save_text) << ",\n"
        << "  \"clipboardSaveImages\": " << bool_str(s.clipboard_save_images) << ",\n"
        << "  \"macroEnabled\": " << bool_str(s.macro_enabled) << ",\n"
        << "  \"macroAutoCaps\": " << bool_str(s.macro_auto_caps) << ",\n"
        << "  \"macroInEnglishMode\": " << bool_str(s.macro_in_english_mode) << "\n"
        << "}\n";
    return output.good();
}

bool SettingsStore::reset() const {
    std::error_code error;
    std::filesystem::remove(path_, error);
    return !error;
}

} // namespace skey::windows
