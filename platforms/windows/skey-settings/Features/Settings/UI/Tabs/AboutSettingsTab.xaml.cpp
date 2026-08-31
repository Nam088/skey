#include "pch.h"
#include "AboutSettingsTab.xaml.h"
#if __has_include("AboutSettingsTab.xaml.g.cpp")
#include "AboutSettingsTab.xaml.g.cpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

AboutSettingsTab::AboutSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
}

void AboutSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {}

void AboutSettingsTab::OnCheckUpdatesClicked(winrt::Windows::Foundation::IInspectable const&,
                                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // UpdateCheckerService equivalent is not available on Windows yet; gate on
    // vm_->settings().check_updates once it lands.
}

} // namespace winrt::SKey::Settings::implementation
#endif
