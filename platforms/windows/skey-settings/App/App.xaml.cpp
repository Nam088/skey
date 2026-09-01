#include "pch.h"
#include "App.xaml.h"
#ifdef _WIN32
#include "MainWindow.xaml.h"

#include <winrt/Microsoft.UI.Xaml.h>

namespace winrt::SKey::Settings::implementation {

App::App() {
    InitializeComponent();
}

void App::OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const&) {
    window_ = winrt::make<MainWindow>();
    window_.Activate();
}

} // namespace winrt::SKey::Settings::implementation
#endif
