#pragma once

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct GeneralSettingsTab {
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

private:
    void OnLaunchAtLoginToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnCheckUpdatesToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnDebugModeToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnExportClicked(winrt::Windows::Foundation::IInspectable const& sender,
                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnImportClicked(winrt::Windows::Foundation::IInspectable const& sender,
                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnFactoryResetClicked(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
};

} // namespace winrt::SKey::Settings::implementation
