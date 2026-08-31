#include "pch.h"
#include "KeyboardSettingsTab.xaml.h"
#if __has_include("KeyboardSettingsTab.xaml.g.cpp")
#include "KeyboardSettingsTab.xaml.g.cpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../Shared/Shortcuts/HotkeyStore.h"

#include <string>

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

KeyboardSettingsTab::KeyboardSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
}

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;

void KeyboardSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                       winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    loading_ = true;
    const auto& s = vm_->settings();

    const auto method_index = [](skey::windows::InputMethod method) {
        switch (method) {
        case skey::windows::InputMethod::simple_telex: return 1;
        case skey::windows::InputMethod::vni: return 2;
        case skey::windows::InputMethod::viqr: return 3;
        default: return 0;
        }
    };
    InputMethodCombo().SelectedIndex(method_index(s.input_method));

    const auto charset_index = [](const std::string& charset) {
        if (charset == "tcvn3") return 1;
        if (charset == "vni-windows") return 2;
        return 0;
    };
    CharsetCombo().SelectedIndex(charset_index(s.charset));

    VietnameseToggle().IsOn(s.is_vietnamese);
    SpellCheckToggle().IsOn(s.spell_check);
    FreeMarkingToggle().IsOn(s.free_marking);
    ModernStyleToggle().IsOn(s.modern_style);
    SwallowedKeyRestoreToggle().IsOn(s.swallowed_key_restore);
    ZfwjToggle().IsOn(s.allow_consonant_zfwj);
    QuickTelexToggle().IsOn(s.quick_telex);
    QuickStartConsonantToggle().IsOn(s.quick_start_consonant);
    QuickEndConsonantToggle().IsOn(s.quick_end_consonant);
    UpperCaseFirstToggle().IsOn(s.upper_case_first_char);
    SmartAppSwitchToggle().IsOn(s.smart_app_switch);
    ImeBrowsersToggle().IsOn(s.use_ime_for_browsers);
    ExclusionEnabledToggle().IsOn(s.app_exclusion_enabled);

    SelectSubTab(0);
    RefreshLanguageToggleRow();
    RefreshExcludedApps();
    loading_ = false;
}

void KeyboardSettingsTab::OnSubTabInputMethodClicked(winrt::Windows::Foundation::IInspectable const&,
                                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SelectSubTab(0);
}

void KeyboardSettingsTab::OnSubTabTypingRulesClicked(winrt::Windows::Foundation::IInspectable const&,
                                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SelectSubTab(1);
}

void KeyboardSettingsTab::OnSubTabAppManagementClicked(winrt::Windows::Foundation::IInspectable const&,
                                                        winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SelectSubTab(2);
}

void KeyboardSettingsTab::SelectSubTab(int index) {
    InputMethodPanel().Visibility(index == 0 ? Visibility::Visible : Visibility::Collapsed);
    TypingRulesPanel().Visibility(index == 1 ? Visibility::Visible : Visibility::Collapsed);
    AppManagementPanel().Visibility(index == 2 ? Visibility::Visible : Visibility::Collapsed);
}

void KeyboardSettingsTab::OnInputMethodChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 0: vm_->set_input_method(skey::windows::InputMethod::telex); break;
    case 1: vm_->set_input_method(skey::windows::InputMethod::simple_telex); break;
    case 2: vm_->set_input_method(skey::windows::InputMethod::vni); break;
    case 3: vm_->set_input_method(skey::windows::InputMethod::viqr); break;
    }
}

void KeyboardSettingsTab::OnCharsetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 0: vm_->set_charset("unicode"); break;
    case 1: vm_->set_charset("tcvn3"); break;
    case 2: vm_->set_charset("vni-windows"); break;
    }
}

void KeyboardSettingsTab::OnVietnameseToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_vietnamese(sender.IsOn());
}

void KeyboardSettingsTab::OnLanguageTogglePresetChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                         winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    const int index = combo.SelectedIndex();
    const auto& presets = skey::windows::HotkeyStore::presets_for(skey::windows::hotkey_action::toggle_language);
    if (index < 0 || index >= static_cast<int>(presets.size())) return;
    const auto& preset = presets[static_cast<std::size_t>(index)];
    vm_->set_hotkey(skey::windows::HotkeyRecord{
        std::string{skey::windows::hotkey_action::toggle_language}, preset.record.vk, preset.record.modifiers});
    RefreshLanguageToggleRow();
}

void KeyboardSettingsTab::OnSpellCheckToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_spell_check(sender.IsOn());
}

void KeyboardSettingsTab::OnFreeMarkingToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_free_marking(sender.IsOn());
}

void KeyboardSettingsTab::OnModernStyleToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_modern_style(sender.IsOn());
}

void KeyboardSettingsTab::OnSwallowedKeyRestoreToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_swallowed_key_restore(sender.IsOn());
}

void KeyboardSettingsTab::OnZfwjToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_allow_consonant_zfwj(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickTelexToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_quick_telex(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickStartConsonantToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_quick_start_consonant(sender.IsOn());
}

void KeyboardSettingsTab::OnQuickEndConsonantToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_quick_end_consonant(sender.IsOn());
}

void KeyboardSettingsTab::OnUpperCaseFirstCharToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_upper_case_first_char(sender.IsOn());
}

void KeyboardSettingsTab::OnSmartAppSwitchToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_smart_app_switch(sender.IsOn());
}

void KeyboardSettingsTab::OnImeBrowsersToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_use_ime_for_browsers(sender.IsOn());
}

void KeyboardSettingsTab::OnExclusionEnabledToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_app_exclusion_enabled(sender.IsOn());
}

void KeyboardSettingsTab::OnAddExcludedAppClicked(winrt::Windows::Foundation::IInspectable const&,
                                                   winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    const auto name = skey::windows::excluded_apps::normalize(winrt::to_string(AddExcludedAppBox().Text()));
    if (name.empty()) return;
    vm_->add_excluded_app(name);
    AddExcludedAppBox().Text(L"");
    RefreshExcludedApps();
}

void KeyboardSettingsTab::OnRemoveSelectedExcludedAppClicked(winrt::Windows::Foundation::IInspectable const&,
                                                              winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    const auto index = ExcludedAppsList().SelectedIndex();
    const auto& apps = vm_->settings().excluded_apps;
    if (index < 0 || index >= static_cast<int>(apps.size())) return;
    vm_->remove_excluded_app(apps[static_cast<std::size_t>(index)]);
    RefreshExcludedApps();
}

void KeyboardSettingsTab::OnClearExcludedAppsClicked(winrt::Windows::Foundation::IInspectable const&,
                                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    vm_->set_excluded_apps({});
    RefreshExcludedApps();
}

void KeyboardSettingsTab::RefreshExcludedApps() {
    if (!vm_) return;
    auto items = ExcludedAppsList().Items();
    items.Clear();
    for (const auto& app : vm_->settings().excluded_apps) {
        items.Append(winrt::box_value(winrt::to_hstring(app)));
    }
    const auto count = vm_->settings().excluded_apps.size();
    ExcludedAppsCountText().Text(winrt::to_hstring(
        count == 0 ? std::string{"No excluded applications"}
                   : std::to_string(count) + " applications configured"));
}

void KeyboardSettingsTab::RefreshLanguageToggleRow() {
    if (!vm_) return;
    const auto* stored = vm_->hotkey_for(std::string{skey::windows::hotkey_action::toggle_language});
    const auto fallback = skey::windows::HotkeyStore::default_record(skey::windows::hotkey_action::toggle_language);
    const auto& current = stored ? *stored : fallback;
    LanguageToggleHotkeyText().Text(winrt::to_hstring(skey::windows::HotkeyFormat::format(current)));
    int index = -1;
    const auto& presets = skey::windows::HotkeyStore::presets_for(skey::windows::hotkey_action::toggle_language);
    for (std::size_t i = 0; i < presets.size(); ++i) {
        if (skey::windows::HotkeyStore::same_hotkey(presets[i].record, current)) {
            index = static_cast<int>(i);
            break;
        }
    }
    LanguageTogglePresetCombo().SelectedIndex(index);
}

} // namespace winrt::SKey::Settings::implementation
#endif
