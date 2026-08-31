#pragma once

#include "SnippetsSettingsTab.xaml.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../../Shared/Settings/MacroStore.h"
#include "../../../../ViewModels/SettingsViewModel.h"

#include <optional>
#include <string>

namespace winrt::SKey::Settings::implementation {

struct SnippetsSettingsTab : SnippetsSettingsTabT<SnippetsSettingsTab> {
    SnippetsSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnEnableToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnAutoCapsToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnEnglishModeToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnAddFieldChanged(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::Controls::TextChangedEventArgs const& args);
    void OnAddClicked(winrt::Windows::Foundation::IInspectable const& sender,
                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSearchChanged(winrt::Windows::Foundation::IInspectable const& sender,
                         winrt::Microsoft::UI::Xaml::Controls::TextChangedEventArgs const& args);

    void RefreshList();
    winrt::Microsoft::UI::Xaml::UIElement BuildRow(const skey::windows::MacroEntry& entry);
    winrt::Microsoft::UI::Xaml::UIElement BuildEditRow(const skey::windows::MacroEntry& entry);

    skey::windows::SettingsViewModel* vm_{nullptr};
    std::optional<skey::windows::MacroStore> store_;
    std::string search_text_;
    std::optional<std::string> editing_trigger_;
    bool syncing_{false};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct SnippetsSettingsTab : SnippetsSettingsTabT<SnippetsSettingsTab, implementation::SnippetsSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
