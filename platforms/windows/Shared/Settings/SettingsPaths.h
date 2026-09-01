#pragma once

#include <filesystem>

namespace skey::windows {

// Single source of truth for where skey-tray.exe and SKey.Settings.exe keep
// their shared files. Unpackaged WinUI apps resolve ApplicationData to a
// per-executable folder, so both processes must use one fixed location:
//   %LOCALAPPDATA%\SKey\settings.json
//   %LOCALAPPDATA%\SKey\macros.json
//   %LOCALAPPDATA%\SKey\clipboard.json
//   %LOCALAPPDATA%\SKey\update_state.json
class SettingsPaths final {
public:
    static std::filesystem::path data_dir();
    static std::filesystem::path settings_file();
    static std::filesystem::path macros_file();
    static std::filesystem::path clipboard_file();
    static std::filesystem::path update_state_file();
};

} // namespace skey::windows
