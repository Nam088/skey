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
}

namespace skey::windows {

SettingsStore::SettingsStore(std::filesystem::path path) : path_(std::move(path)) {}

SettingsModel SettingsStore::load() const {
    // The first implementation deliberately fails closed to defaults. A later
    // schema reader can be added without changing callers or the IPC contract.
    std::ifstream input(path_);
    if (!input.good()) return {};
    std::ostringstream buffer;
    buffer << input.rdbuf();
    const auto text = buffer.str();
    SettingsModel result{};
    const auto locale = value_for(text, "locale");
    const auto theme = value_for(text, "theme");
    const auto method = value_for(text, "inputMethod");
    if (locale == "en-US") result.locale = Locale::en_us;
    if (theme == "light") result.theme = ThemeMode::light;
    else if (theme == "dark") result.theme = ThemeMode::dark;
    if (method == "vni") result.input_method = InputMethod::vni;
    else if (method == "viqr") result.input_method = InputMethod::viqr;
    else if (method == "simpleTelex") result.input_method = InputMethod::simple_telex;
    const auto charset = value_for(text, "charset");
    if (!charset.empty()) result.charset = charset;
    return result;
}

bool SettingsStore::save(const SettingsModel& settings) const {
    std::error_code error;
    if (!path_.parent_path().empty()) {
        std::filesystem::create_directories(path_.parent_path(), error);
        if (error) return false;
    }
    std::ofstream output(path_, std::ios::trunc);
    if (!output.good()) return false;
    const auto locale = settings.locale == Locale::en_us ? "en-US" : "vi-VN";
    const auto theme = settings.theme == ThemeMode::dark ? "dark" : settings.theme == ThemeMode::light ? "light" : "system";
    const auto method = settings.input_method == InputMethod::vni ? "vni" : settings.input_method == InputMethod::viqr ? "viqr" : settings.input_method == InputMethod::simple_telex ? "simpleTelex" : "telex";
    output << "{\n  \"schemaVersion\": " << settings.schema_version << ",\n  \"locale\": \"" << locale << "\",\n  \"theme\": \"" << theme << "\",\n  \"inputMethod\": \"" << method << "\",\n  \"charset\": \"" << settings.charset << "\",\n  \"isVietnamese\": " << (settings.is_vietnamese ? "true" : "false") << "\n}\n";
    return output.good();
}

bool SettingsStore::reset() const {
    std::error_code error;
    std::filesystem::remove(path_, error);
    return !error;
}

} // namespace skey::windows
