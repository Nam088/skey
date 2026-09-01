#include "pch.h"
#include "ShortcutsSettingsTab.xaml.h"
#if __has_include("ShortcutsSettingsTab.g.cpp")
#include "ShortcutsSettingsTab.g.cpp"
#endif
#if __has_include("ShortcutsSettingsTab.xaml.g.hpp")
#include "ShortcutsSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.Core.h>

#include "../../../../Shared/Shortcuts/HotkeyStore.h"

#include <string>

#include "../../../../ViewModels/SharedViewModel.h"
#include "../../../../Shared/Logging/AppLogger.h"

namespace winrt::SKey::Settings::implementation {

ShortcutsSettingsTab::ShortcutsSettingsTab() {
    SKEY_LOG_INFO("ShortcutsSettingsTab() constructing...");
    loading_ = true;
    try {
        vm_ = &skey::windows::shared_view_model();
    } catch (...) {}
    InitializeComponent();
    SKEY_LOG_INFO("ShortcutsSettingsTab::InitializeComponent() succeeded.");
}

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;

void ShortcutsSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                        winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SKEY_LOG_INFO("ShortcutsSettingsTab::Page_Loaded() starting...");
    if (!vm_) return;
    loading_ = true;
    try {
        if (auto toggle = CleanerEnabledToggle()) {
            toggle.IsOn(vm_->settings().cleaner_enabled);
        }
        RefreshAllRows();
        UpdateRecordButtons();
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("ShortcutsSettingsTab::Page_Loaded exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("ShortcutsSettingsTab::Page_Loaded unknown exception");
    }
    loading_ = false;
    SKEY_LOG_INFO("ShortcutsSettingsTab::Page_Loaded() completed.");
}

void ShortcutsSettingsTab::OnCleanerEnabledToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_cleaner_enabled(toggle.IsOn());
    RefreshAllRows();
}

void ShortcutsSettingsTab::OnToggleLanguagePresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                          winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (loading_) return;
    ApplyPreset(skey::windows::hotkey_action::toggle_language, sender.as<ComboBox>().SelectedIndex());
}

void ShortcutsSettingsTab::OnClipboardPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                     winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (loading_) return;
    ApplyPreset(skey::windows::hotkey_action::clipboard, sender.as<ComboBox>().SelectedIndex());
}

void ShortcutsSettingsTab::OnCleanerPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                   winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (loading_) return;
    ApplyPreset(skey::windows::hotkey_action::cleaner, sender.as<ComboBox>().SelectedIndex());
}

void ShortcutsSettingsTab::OnAiPresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                              winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (loading_) return;
    ApplyPreset(skey::windows::hotkey_action::ai, sender.as<ComboBox>().SelectedIndex());
}

void ShortcutsSettingsTab::OnRecordToggleLanguageClicked(winrt::Windows::Foundation::IInspectable const&,
                                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    StartRecording(std::string{skey::windows::hotkey_action::toggle_language});
}

void ShortcutsSettingsTab::OnRecordClipboardClicked(winrt::Windows::Foundation::IInspectable const&,
                                                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    StartRecording(std::string{skey::windows::hotkey_action::clipboard});
}

void ShortcutsSettingsTab::OnRecordCleanerClicked(winrt::Windows::Foundation::IInspectable const&,
                                                   winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    StartRecording(std::string{skey::windows::hotkey_action::cleaner});
}

void ShortcutsSettingsTab::OnRecordAiClicked(winrt::Windows::Foundation::IInspectable const&,
                                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    StartRecording(std::string{skey::windows::hotkey_action::ai});
}

void ShortcutsSettingsTab::OnRecordTranslateClicked(winrt::Windows::Foundation::IInspectable const&,
                                                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    StartRecording(std::string{skey::windows::hotkey_action::translate});
}

void ShortcutsSettingsTab::OnRecorderKeyDown(winrt::Windows::Foundation::IInspectable const&,
                                             winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args) {
    if (recording_action_.empty()) return;
    const auto vk = static_cast<unsigned>(args.Key());
    const auto modifiers = CurrentModifiers();
    const auto ended = IsModifierKey(vk)
        ? recorder_.on_modifiers_changed(modifiers)
        : recorder_.on_key_down(vk, modifiers);
    args.Handled(true);
    if (ended) FinishRecording();
}

void ShortcutsSettingsTab::OnRecorderKeyUp(winrt::Windows::Foundation::IInspectable const&,
                                           winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args) {
    if (recording_action_.empty()) return;
    const auto vk = static_cast<unsigned>(args.Key());
    if (!IsModifierKey(vk)) return;
    const auto ended = recorder_.on_modifiers_changed(CurrentModifiers());
    args.Handled(true);
    if (ended) FinishRecording();
}

void ShortcutsSettingsTab::ApplyPreset(std::string_view action, int index) {
    if (!vm_) return;
    const auto& presets = skey::windows::HotkeyStore::presets_for(action);
    if (index < 0 || index >= static_cast<int>(presets.size())) return;
    const auto& preset = presets[static_cast<std::size_t>(index)];
    vm_->set_hotkey(skey::windows::HotkeyRecord{std::string{action}, preset.record.vk, preset.record.modifiers});
    RefreshAllRows();
}

void ShortcutsSettingsTab::StartRecording(std::string action) {
    if (recording_action_ == action) {
        recording_action_.clear();
        recorder_.cancel();
        UpdateRecordButtons();
        return;
    }
    recording_action_ = std::move(action);
    recorder_.begin();
    UpdateRecordButtons();
}

void ShortcutsSettingsTab::FinishRecording() {
    const auto action = recording_action_;
    recording_action_.clear();
    UpdateRecordButtons();
    if (!vm_ || !recorder_.captured().has_value()) return;
    const auto& captured = *recorder_.captured();
    vm_->set_hotkey(skey::windows::HotkeyRecord{action, captured.vk, captured.modifiers});
    RefreshAllRows();
}

void ShortcutsSettingsTab::UpdateRecordButtons() {
    const auto apply = [this](Button const& button, std::string_view action) {
        const bool active = recording_action_ == action;
        button.Content(winrt::box_value(active ? L"Press keys... (Esc to cancel)" : L"Change..."));
    };
    apply(RecordToggleLanguageButton(), skey::windows::hotkey_action::toggle_language);
    apply(RecordClipboardButton(), skey::windows::hotkey_action::clipboard);
    apply(RecordCleanerButton(), skey::windows::hotkey_action::cleaner);
    apply(RecordAiButton(), skey::windows::hotkey_action::ai);
    apply(RecordTranslateButton(), skey::windows::hotkey_action::translate);
}

unsigned ShortcutsSettingsTab::CurrentModifiers() const {
    using winrt::Microsoft::UI::Input::InputKeyboardSource;
    using winrt::Windows::System::VirtualKey;
    using winrt::Windows::UI::Core::CoreVirtualKeyStates;
    const auto down = [](VirtualKey key) {
        const auto state = InputKeyboardSource::GetKeyStateForCurrentThread(key);
        return (state & CoreVirtualKeyStates::Down) == CoreVirtualKeyStates::Down;
    };
    unsigned modifiers = 0;
    if (down(VirtualKey::Shift)) modifiers |= skey::windows::hotkey_mod::shift;
    if (down(VirtualKey::Control)) modifiers |= skey::windows::hotkey_mod::ctrl;
    if (down(VirtualKey::Menu)) modifiers |= skey::windows::hotkey_mod::alt;
    if (down(VirtualKey::LeftWindows) || down(VirtualKey::RightWindows)) {
        modifiers |= skey::windows::hotkey_mod::win;
    }
    return modifiers;
}

bool ShortcutsSettingsTab::IsModifierKey(unsigned vk) {
    return vk == 0x10 || vk == 0x11 || vk == 0x12 || vk == 0x5B || vk == 0x5C
        || (vk >= 0xA0 && vk <= 0xA5);
}

void ShortcutsSettingsTab::OnTranslatePresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                    winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    ApplyPreset(skey::windows::hotkey_action::translate, combo.SelectedIndex());
}

void ShortcutsSettingsTab::RefreshAllRows() {
    if (!vm_) return;
    const auto language = RefreshRow(skey::windows::hotkey_action::toggle_language,
                                     HotkeyToggleLanguageText(), ConflictToggleLanguageText());
    SelectPresetIndex(PresetToggleLanguageCombo(), skey::windows::hotkey_action::toggle_language, language);
    const auto clipboard = RefreshRow(skey::windows::hotkey_action::clipboard,
                                      HotkeyClipboardText(), ConflictClipboardText());
    SelectPresetIndex(PresetClipboardCombo(), skey::windows::hotkey_action::clipboard, clipboard);
    const auto cleaner = RefreshRow(skey::windows::hotkey_action::cleaner,
                                    HotkeyCleanerText(), ConflictCleanerText());
    SelectPresetIndex(PresetCleanerCombo(), skey::windows::hotkey_action::cleaner, cleaner);
    const auto ai = RefreshRow(skey::windows::hotkey_action::ai, HotkeyAiText(), ConflictAiText());
    SelectPresetIndex(PresetAiCombo(), skey::windows::hotkey_action::ai, ai);
    const auto translate = RefreshRow(skey::windows::hotkey_action::translate, HotkeyTranslateText(), ConflictTranslateText());
    SelectPresetIndex(PresetTranslateCombo(), skey::windows::hotkey_action::translate, translate);
}

skey::windows::HotkeyRecord ShortcutsSettingsTab::RefreshRow(std::string_view action,
                                                              TextBlock const& combo_text,
                                                              TextBlock const& conflict_text) {
    if (!vm_) return {};
    const auto* stored = vm_->hotkey_for(std::string{action});
    const auto fallback = skey::windows::HotkeyStore::default_record(action);
    const auto current = stored ? *stored : fallback;
    combo_text.Text(winrt::to_hstring(skey::windows::HotkeyFormat::format(current)));

    std::string warning;
    const auto other = skey::windows::HotkeyStore::find_conflict(
        vm_->settings().hotkeys, current, action, vm_->settings().cleaner_enabled);
    if (other.has_value()) {
        const auto* other_record = vm_->hotkey_for(*other);
        warning = "Conflicts with: ";
        warning += other_record ? skey::windows::HotkeyFormat::format(*other_record) : *other;
    }
    conflict_text.Text(winrt::to_hstring(warning));
    conflict_text.Visibility(warning.empty() ? Visibility::Collapsed : Visibility::Visible);
    return current;
}

void ShortcutsSettingsTab::SelectPresetIndex(ComboBox const& presets,
                                              std::string_view action,
                                              const skey::windows::HotkeyRecord& current) {
    int index = -1;
    const auto& preset_list = skey::windows::HotkeyStore::presets_for(action);
    for (std::size_t i = 0; i < preset_list.size(); ++i) {
        if (skey::windows::HotkeyStore::same_hotkey(preset_list[i].record, current)) {
            index = static_cast<int>(i);
            break;
        }
    }
    presets.SelectedIndex(index);
}

} // namespace winrt::SKey::Settings::implementation
#endif
