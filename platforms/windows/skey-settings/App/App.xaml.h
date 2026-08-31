#pragma once

#include <winrt/Microsoft.UI.Xaml.h>

namespace winrt::SKey::Settings::implementation {
struct App : winrt::Microsoft::UI::Xaml::ApplicationT<App> {
    void OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);
};
}
