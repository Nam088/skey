#pragma once

#include "ToolsSettingsTab.xaml.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct ToolsSettingsTab : ToolsSettingsTabT<ToolsSettingsTab> {
    ToolsSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnCleanerEnabledToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnCleanNowClicked(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickTransformClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnConvertClicked(winrt::Windows::Foundation::IInspectable const& sender,
                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct ToolsSettingsTab : ToolsSettingsTabT<ToolsSettingsTab, implementation::ToolsSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
