#pragma once

#include "App.xaml.g.h"

namespace winrt::SKey::Settings::implementation {
struct App : AppT<App> {
    App();
    void OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);

private:
    winrt::Microsoft::UI::Xaml::Window window_{nullptr};
};
} // namespace winrt::SKey::Settings::implementation
