#pragma once

#include "AppearanceSettingsTab.xaml.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct AppearanceSettingsTab : AppearanceSettingsTabT<AppearanceSettingsTab> {
    AppearanceSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnThemeSystemChecked(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnThemeLightChecked(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnThemeDarkChecked(winrt::Windows::Foundation::IInspectable const& sender,
                            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct AppearanceSettingsTab : AppearanceSettingsTabT<AppearanceSettingsTab, implementation::AppearanceSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
