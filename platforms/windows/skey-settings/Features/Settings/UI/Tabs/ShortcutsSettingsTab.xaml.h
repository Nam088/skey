#pragma once

#include "ShortcutsSettingsTab.xaml.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include "../../../../ViewModels/SettingsViewModel.h"
#include "../../../../Shared/Shortcuts/ShortcutRecorderModel.h"

#include <string>
#include <string_view>

namespace winrt::SKey::Settings::implementation {

struct ShortcutsSettingsTab : ShortcutsSettingsTabT<ShortcutsSettingsTab> {
    ShortcutsSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnCleanerEnabledToggled(winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnToggleLanguagePresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                       winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnClipboardPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                  winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnCleanerPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnAiPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnRecordToggleLanguageClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                       winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnRecordClipboardClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnRecordCleanerClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnRecordAiClicked(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnRecordTranslateClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnPreviewKeyDown(winrt::Windows::Foundation::IInspectable const& sender,
                          winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args);
    void OnPreviewKeyUp(winrt::Windows::Foundation::IInspectable const& sender,
                        winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args);

    void ApplyPreset(std::string_view action, int index);
    void StartRecording(std::string action);
    void FinishRecording();
    void UpdateRecordButtons();
    unsigned CurrentModifiers() const;
    static bool IsModifierKey(unsigned vk);
    void RefreshAllRows();
    skey::windows::HotkeyRecord RefreshRow(std::string_view action,
                                           winrt::Microsoft::UI::Xaml::Controls::TextBlock const& combo_text,
                                           winrt::Microsoft::UI::Xaml::Controls::TextBlock const& conflict_text);
    void SelectPresetIndex(winrt::Microsoft::UI::Xaml::Controls::ComboBox const& presets,
                           std::string_view action,
                           const skey::windows::HotkeyRecord& current);

    skey::windows::SettingsViewModel* vm_{nullptr};
    skey::windows::ShortcutRecorderModel recorder_{};
    std::string recording_action_{};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct ShortcutsSettingsTab : ShortcutsSettingsTabT<ShortcutsSettingsTab, implementation::ShortcutsSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
