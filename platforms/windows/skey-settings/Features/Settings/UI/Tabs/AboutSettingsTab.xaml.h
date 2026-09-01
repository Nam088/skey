#pragma once

#include "AboutSettingsTab.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct AboutSettingsTab : AboutSettingsTabT<AboutSettingsTab> {
    AboutSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnCheckUpdatesClicked(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct AboutSettingsTab : AboutSettingsTabT<AboutSettingsTab, implementation::AboutSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
