#pragma once

#include "AiSettingsTab.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct AiSettingsTab : AiSettingsTabT<AiSettingsTab> {
    AiSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnPreferredEngineChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                  winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnPreferredEngineApiKeyChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                        winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnTargetLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                 winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnAutoDetectToggled(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnEngineEnabledToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnEngineApiKeyChanged(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct AiSettingsTab : AiSettingsTabT<AiSettingsTab, implementation::AiSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
