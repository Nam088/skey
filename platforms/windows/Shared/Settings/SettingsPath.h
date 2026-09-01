#pragma once

#ifdef _WIN32
#include <windows.h>
#include <shlobj.h>

#include <filesystem>

namespace skey::windows {

inline std::filesystem::path default_settings_path() {
    wchar_t* local_app_data = nullptr;
    if (SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local_app_data) != S_OK) {
        return {};
    }
    std::filesystem::path path =
        std::filesystem::path(local_app_data) / L"skey" / L"settings.json";
    CoTaskMemFree(local_app_data);
    return path;
}

} // namespace skey::windows
#endif
