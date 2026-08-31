#pragma once

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct KeyboardSettingsTab {
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

private:
    void OnInputMethodChanged(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnCharsetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                          winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnVietnameseToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSpellCheckToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnFreeMarkingToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnModernStyleToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSwallowedKeyRestoreToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickTelexToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickStartConsonantToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickEndConsonantToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnUpperCaseFirstCharToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSmartAppSwitchToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
};

} // namespace winrt::SKey::Settings::implementation
