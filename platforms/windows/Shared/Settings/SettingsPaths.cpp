#include "SettingsPaths.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#endif

namespace skey::windows {

std::filesystem::path SettingsPaths::data_dir() {
#ifdef _WIN32
    wchar_t* raw = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &raw)) && raw != nullptr) {
        std::filesystem::path dir(raw);
        CoTaskMemFree(raw);
        return dir / L"SKey";
    }
    return std::filesystem::temp_directory_path() / L"SKey";
#else
    return std::filesystem::temp_directory_path() / "skey-settings";
#endif
}

std::filesystem::path SettingsPaths::settings_file() {
    return data_dir() / "settings.json";
}

std::filesystem::path SettingsPaths::macros_file() {
    return data_dir() / "macros.json";
}

std::filesystem::path SettingsPaths::clipboard_file() {
    return data_dir() / "clipboard.json";
}

} // namespace skey::windows
