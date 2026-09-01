#pragma once

#include "KeyboardSettingsTab.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct KeyboardSettingsTab : KeyboardSettingsTabT<KeyboardSettingsTab> {
    KeyboardSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnSubTabInputMethodClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSubTabTypingRulesClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSubTabAppManagementClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnInputMethodChanged(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnCharsetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                          winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnVietnameseToggled(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnLanguageTogglePresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                       winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnSpellCheckToggled(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnFreeMarkingToggled(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnModernStyleToggled(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSwallowedKeyRestoreToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnZfwjToggled(winrt::Windows::Foundation::IInspectable const& sender,
                       winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickTelexToggled(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickStartConsonantToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnQuickEndConsonantToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnUpperCaseFirstCharToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSmartAppSwitchToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnImeBrowsersToggled(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnExclusionEnabledToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                   winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnAddExcludedAppClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnRemoveSelectedExcludedAppClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnClearExcludedAppsClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void SelectSubTab(int index);
    void RefreshExcludedApps();
    void RefreshLanguageToggleRow();

    skey::windows::SettingsViewModel* vm_{nullptr};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct KeyboardSettingsTab : KeyboardSettingsTabT<KeyboardSettingsTab, implementation::KeyboardSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
