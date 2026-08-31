#include "KeyboardSettingsTab.xaml.h"

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml::Controls;

void KeyboardSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                       winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // ViewModel is injected by the host frame via x:Bind or code.
    // Toggle states are read from ViewModel on load and written back on Toggled events.
}

void KeyboardSettingsTab::OnInputMethodChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 0: vm_->set_input_method(skey::windows::InputMethod::telex); break;
    case 1: vm_->set_input_method(skey::windows::InputMethod::simple_telex); break;
    case 2: vm_->set_input_method(skey::windows::InputMethod::vni); break;
    case 3: vm_->set_input_method(skey::windows::InputMethod::viqr); break;
    }
}

void KeyboardSettingsTab::OnCharsetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 0: vm_->set_charset("unicode"); break;
    case 1: vm_->set_charset("tcvn3"); break;
    case 2: vm_->set_charset("vni-windows"); break;
    }
}

void KeyboardSettingsTab::OnVietnameseToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_vietnamese(sender.IsOn());
}

void KeyboardSettingsTab::OnSpellCheckToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_spell_check(sender.IsOn());
}

void KeyboardSettingsTab::OnFreeMarkingToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_free_marking(sender.IsOn());
}

void KeyboardSettingsTab::OnModernStyleToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_modern_style(sender.IsOn());
}

void KeyboardSettingsTab::OnSwallowedKeyRestoreToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_swallowed_key_restore(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickTelexToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_quick_telex(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickStartConsonantToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_quick_start_consonant(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickEndConsonantToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_quick_end_consonant(sender.IsOn());
}

void KeyboardSettingsTab::OnUpperCaseFirstCharToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_upper_case_first_char(sender.IsOn());
}

void KeyboardSettingsTab::OnSmartAppSwitchToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->set_smart_app_switch(sender.IsOn());
}

} // namespace winrt::SKey::Settings::implementation
#endif
