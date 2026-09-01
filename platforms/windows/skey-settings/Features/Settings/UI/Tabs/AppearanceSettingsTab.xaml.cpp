#include "pch.h"
#include "AppearanceSettingsTab.xaml.h"
#if __has_include("AppearanceSettingsTab.g.cpp")
#include "AppearanceSettingsTab.g.cpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

AppearanceSettingsTab::AppearanceSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
}

void AppearanceSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    loading_ = true;
    const auto& s = vm_->settings();

    ThemeSystemRadio().IsChecked(s.theme == skey::windows::ThemeMode::system);
    ThemeLightRadio().IsChecked(s.theme == skey::windows::ThemeMode::light);
    ThemeDarkRadio().IsChecked(s.theme == skey::windows::ThemeMode::dark);
    loading_ = false;
}

void AppearanceSettingsTab::OnThemeSystemChecked(winrt::Windows::Foundation::IInspectable const&,
                                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::system);
}

void AppearanceSettingsTab::OnThemeLightChecked(winrt::Windows::Foundation::IInspectable const&,
                                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::light);
}

void AppearanceSettingsTab::OnThemeDarkChecked(winrt::Windows::Foundation::IInspectable const&,
                                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_theme(skey::windows::ThemeMode::dark);
}

} // namespace winrt::SKey::Settings::implementation
#endif
