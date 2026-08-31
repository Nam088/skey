#pragma once

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct ClipboardSettingsTab {
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

private:
    void OnEnableToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnAutoPasteToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnPastePlainTextToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSaveTextToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSaveImagesToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnMaxItemsChanged(winrt::Microsoft::UI::Xaml::Controls::NumberBox const& sender,
                           winrt::Windows::Foundation::IInspectable const& args);
    void OnClearHistoryClicked(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
};

} // namespace winrt::SKey::Settings::implementation
