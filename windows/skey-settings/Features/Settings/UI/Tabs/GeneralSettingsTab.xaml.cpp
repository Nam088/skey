#include "GeneralSettingsTab.xaml.h"

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Windows.Storage.Pickers.h>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml::Controls;

void GeneralSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {}

void GeneralSettingsTab::OnLaunchAtLoginToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_launch_at_login(sender.IsOn());
}

void GeneralSettingsTab::OnCheckUpdatesToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_check_updates(sender.IsOn());
}

void GeneralSettingsTab::OnLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_locale(combo.SelectedIndex() == 0 ? skey::windows::Locale::vi_vn : skey::windows::Locale::en_us);
}

void GeneralSettingsTab::OnDebugModeToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_debug_mode(sender.IsOn());
}

void GeneralSettingsTab::OnExportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // Export settings via file picker - requires WinUI 3 runtime
}

void GeneralSettingsTab::OnImportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // Import settings via file picker - requires WinUI 3 runtime
}

void GeneralSettingsTab::OnFactoryResetClicked(winrt::Windows::Foundation::IInspectable const&,
                                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->reset();
}

} // namespace winrt::SKey::Settings::implementation
#endif
