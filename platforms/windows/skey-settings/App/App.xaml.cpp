#include "App.xaml.h"

#ifdef _WIN32
#include "../../Shared/Settings/SettingsStore.h"
#include <winrt/Microsoft.UI.Xaml.h>

namespace winrt::SKey::Settings::implementation {

void App::OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const&) {
    // Load persisted settings on startup.
    // The SettingsStore path is in AppData/Local/skey/settings.json.
    auto local = winrt::Windows::Storage::ApplicationData::Current().LocalFolder().Path();
    auto path = std::filesystem::path(local.c_str()) / "settings.json";
    skey::windows::SettingsStore store(path);
    auto settings = store.load();
    store.save(settings);
}

} // namespace winrt::SKey::Settings::implementation
#endif
