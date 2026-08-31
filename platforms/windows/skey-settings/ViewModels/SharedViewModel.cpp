#include "SharedViewModel.h"

#include "../../Shared/Settings/SettingsStore.h"

#include <filesystem>

#ifdef _WIN32
#include <windows.h>
#include <winrt/Windows.Storage.h>
#endif

namespace skey::windows {

namespace {
std::filesystem::path settings_path() {
#ifdef _WIN32
    const auto local = winrt::Windows::Storage::ApplicationData::Current().LocalFolder().Path();
    return std::filesystem::path(local.c_str()) / "settings.json";
#else
    return std::filesystem::temp_directory_path() / "skey-settings" / "settings.json";
#endif
}
} // namespace

SettingsViewModel& shared_view_model() {
    static SettingsViewModel instance{SettingsStore{settings_path()}};
    return instance;
}

} // namespace skey::windows
