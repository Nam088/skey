#include "pch.h"
#include "App.xaml.h"
#if __has_include("App.xaml.g.cpp")
#include "App.xaml.g.cpp"
#endif

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

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    winrt::init_apartment(winrt::apartment_type::single_threaded);
    winrt::Microsoft::UI::Xaml::Application::Start(
        [](winrt::Windows::Foundation::IInspectable const&) {
            winrt::make<winrt::SKey::Settings::implementation::App>();
        });
    return 0;
}
#endif
