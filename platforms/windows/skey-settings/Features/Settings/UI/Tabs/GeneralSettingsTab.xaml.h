#pragma once

#include "GeneralSettingsTab.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct GeneralSettingsTab : GeneralSettingsTabT<GeneralSettingsTab> {
    GeneralSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnLaunchAtLoginToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnCheckUpdatesToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnThemeChanged(winrt::Windows::Foundation::IInspectable const& sender,
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
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct GeneralSettingsTab : GeneralSettingsTabT<GeneralSettingsTab, implementation::GeneralSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
