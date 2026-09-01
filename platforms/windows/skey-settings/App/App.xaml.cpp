#include "pch.h"
#include "App.xaml.h"
#define DISABLE_XAML_GENERATED_MAIN
#if __has_include("XamlMetaDataProvider.g.cpp")
#include "XamlMetaDataProvider.g.cpp"
#endif
#if __has_include("XamlLibMetadataProvider.g.cpp")
#include "XamlLibMetadataProvider.g.cpp"
#endif
#if __has_include("XamlTypeInfo.Impl.g.cpp")
#include "XamlTypeInfo.Impl.g.cpp"
#endif
#if __has_include("XamlTypeInfo.g.cpp")
#include "XamlTypeInfo.g.cpp"
#endif
#ifdef _WIN32
#include "MainWindow.xaml.h"
#include "../../Shared/Logging/AppLogger.h"

#include <winrt/Microsoft.UI.Xaml.h>

namespace winrt::SKey::Settings::implementation {

App::App() {
    SKEY_LOG_INFO("App::App() constructing...");
    UnhandledException([](winrt::Windows::Foundation::IInspectable const&, winrt::Microsoft::UI::Xaml::UnhandledExceptionEventArgs const& e) {
        std::wstring msg = e.Message().c_str();
        std::string narrow(msg.begin(), msg.end());
        SKEY_LOG_ERROR("WinUI UnhandledException: " + narrow);
        e.Handled(true);
    });
    try {
        InitializeComponent();
        SKEY_LOG_INFO("App::InitializeComponent() succeeded.");
    } catch (winrt::hresult_error const& ex) {
        std::wstring msg = ex.message().c_str();
        std::string narrow(msg.begin(), msg.end());
        SKEY_LOG_ERROR("App::InitializeComponent HRESULT Exception: " + narrow);
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("App::InitializeComponent std::exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("App::InitializeComponent unknown exception");
    }
}

void App::OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const&) {
    SKEY_LOG_INFO("App::OnLaunched() starting...");
    try {
        window_ = winrt::make<MainWindow>();
        SKEY_LOG_INFO("MainWindow created successfully.");
        window_.Activate();
        SKEY_LOG_INFO("MainWindow activated successfully.");
    } catch (winrt::hresult_error const& ex) {
        std::wstring msg = ex.message().c_str();
        std::string narrow(msg.begin(), msg.end());
        SKEY_LOG_ERROR("App::OnLaunched HRESULT Exception: " + narrow);
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("App::OnLaunched std::exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("App::OnLaunched unknown exception");
    }
}

} // namespace winrt::SKey::Settings::implementation

int __stdcall wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    skey::windows::AppLogger::instance().initialize("skey-settings");
    SKEY_LOG_INFO("==================================================");
    SKEY_LOG_INFO("skey-settings process started.");

    try {
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        SKEY_LOG_INFO("winrt::init_apartment succeeded.");

        ::winrt::Microsoft::UI::Xaml::Application::Start(
            [](auto&&)
            {
                SKEY_LOG_INFO("Application::Start callback running...");
                ::winrt::make<::winrt::SKey::Settings::implementation::App>();
            });
    } catch (winrt::hresult_error const& ex) {
        std::wstring msg = ex.message().c_str();
        std::string narrow(msg.begin(), msg.end());
        SKEY_LOG_FATAL("Fatal wWinMain HRESULT Error: " + narrow);
    } catch (std::exception const& ex) {
        SKEY_LOG_FATAL(std::string("Fatal wWinMain std Error: ") + ex.what());
    } catch (...) {
        SKEY_LOG_FATAL("Fatal wWinMain unknown exception.");
    }
    SKEY_LOG_INFO("skey-settings exiting.");
    return 0;
}
#endif
