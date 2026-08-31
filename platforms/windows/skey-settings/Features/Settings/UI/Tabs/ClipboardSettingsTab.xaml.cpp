#include "ClipboardSettingsTab.xaml.h"

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml::Controls;

void ClipboardSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                        winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {}

void ClipboardSettingsTab::OnEnableToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_clipboard_enabled(sender.IsOn());
}

void ClipboardSettingsTab::OnAutoPasteToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_clipboard_auto_paste(sender.IsOn());
}

void ClipboardSettingsTab::OnPastePlainTextToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_clipboard_paste_plain_text(sender.IsOn());
}

void ClipboardSettingsTab::OnSaveTextToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_clipboard_save_text(sender.IsOn());
}

void ClipboardSettingsTab::OnSaveImagesToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_clipboard_save_images(sender.IsOn());
}

void ClipboardSettingsTab::OnMaxItemsChanged(NumberBox const& sender, winrt::Windows::Foundation::IInspectable const&) {
    if (vm_) vm_->set_clipboard_max_items(static_cast<std::size_t>(sender.Value()));
}

void ClipboardSettingsTab::OnClearHistoryClicked(winrt::Windows::Foundation::IInspectable const&,
                                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // Clear clipboard history via ClipboardService
}

} // namespace winrt::SKey::Settings::implementation
#endif
