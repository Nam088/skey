#include "pch.h"
#include "AppearanceSettingsTab.xaml.h"
#if __has_include("AppearanceSettingsTab.g.cpp")
#include "AppearanceSettingsTab.g.cpp"
#endif
#if __has_include("AppearanceSettingsTab.xaml.g.hpp")
#include "AppearanceSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../ViewModels/SharedViewModel.h"
#include "../../../../Shared/Logging/AppLogger.h"
#include "../../../App/MainWindow.xaml.h"

namespace winrt::SKey::Settings::implementation {

AppearanceSettingsTab::AppearanceSettingsTab() {
    SKEY_LOG_INFO("AppearanceSettingsTab() constructing...");
    loading_ = true;
    try {
        vm_ = &skey::windows::shared_view_model();
    } catch (...) {}
    InitializeComponent();
    SKEY_LOG_INFO("AppearanceSettingsTab::InitializeComponent() succeeded.");
}

void AppearanceSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SKEY_LOG_INFO("AppearanceSettingsTab::Page_Loaded() starting...");
    if (!vm_) return;
    loading_ = true;
    try {
        const auto& s = vm_->settings();

        ThemeSystemRadio().IsChecked(s.theme == skey::windows::ThemeMode::system);
        ThemeLightRadio().IsChecked(s.theme == skey::windows::ThemeMode::light);
        ThemeDarkRadio().IsChecked(s.theme == skey::windows::ThemeMode::dark);
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("AppearanceSettingsTab::Page_Loaded exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("AppearanceSettingsTab::Page_Loaded unknown exception");
    }
    loading_ = false;
    SKEY_LOG_INFO("AppearanceSettingsTab::Page_Loaded() completed.");
}

void AppearanceSettingsTab::OnThemeSystemChecked(winrt::Windows::Foundation::IInspectable const&,
                                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::system);
    MainWindow::ApplyTheme(skey::windows::ThemeMode::system);
}

void AppearanceSettingsTab::OnThemeLightChecked(winrt::Windows::Foundation::IInspectable const&,
                                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::light);
    MainWindow::ApplyTheme(skey::windows::ThemeMode::light);
}

void AppearanceSettingsTab::OnThemeDarkChecked(winrt::Windows::Foundation::IInspectable const&,
                                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::dark);
    MainWindow::ApplyTheme(skey::windows::ThemeMode::dark);
}

} // namespace winrt::SKey::Settings::implementation
#endif
