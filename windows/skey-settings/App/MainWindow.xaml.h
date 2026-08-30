#pragma once

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {
struct MainWindow {
    skey::windows::SettingsViewModel ViewModel{};
    void NavigateForTag(winrt::hstring const& tag);
};
}
