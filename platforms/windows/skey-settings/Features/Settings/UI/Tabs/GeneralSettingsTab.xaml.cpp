#include "pch.h"
#include "GeneralSettingsTab.xaml.h"
#if __has_include("GeneralSettingsTab.g.cpp")
#include "GeneralSettingsTab.g.cpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Windows.Storage.Pickers.h>

#include "../../../../Shared/Settings/Backup/SettingsBackup.h"

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

GeneralSettingsTab::GeneralSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
}

using namespace winrt::Microsoft::UI::Xaml::Controls;

void GeneralSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    loading_ = true;
    const auto& s = vm_->settings();

    LaunchAtLoginToggle().IsOn(s.launch_at_login);
    LanguageCombo().SelectedIndex(s.locale == skey::windows::Locale::en_us ? 1 : 0);

    const auto theme_index = [](skey::windows::ThemeMode theme) {
        switch (theme) {
        case skey::windows::ThemeMode::light: return 1;
        case skey::windows::ThemeMode::dark: return 2;
        default: return 0;
        }
    };
    ThemeCombo().SelectedIndex(theme_index(s.theme));

    CheckUpdatesToggle().IsOn(s.check_updates);
    DebugModeToggle().IsOn(s.debug_mode);
    loading_ = false;
}

void GeneralSettingsTab::OnLaunchAtLoginToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_launch_at_login(toggle.IsOn());
}

void GeneralSettingsTab::OnCheckUpdatesToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_check_updates(toggle.IsOn());
}

void GeneralSettingsTab::OnLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_locale(combo.SelectedIndex() == 0 ? skey::windows::Locale::vi_vn : skey::windows::Locale::en_us);
}

void GeneralSettingsTab::OnThemeChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                        winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 1: vm_->set_theme(skey::windows::ThemeMode::light); break;
    case 2: vm_->set_theme(skey::windows::ThemeMode::dark); break;
    default: vm_->set_theme(skey::windows::ThemeMode::system); break;
    }
}

void GeneralSettingsTab::OnDebugModeToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_debug_mode(toggle.IsOn());
}

void GeneralSettingsTab::OnExportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    // FileSavePicker resolves the destination (NSSavePanel equivalent) and requires
    // the WinUI 3 runtime; feed the chosen path here.
    const auto destination = std::filesystem::temp_directory_path()
        / skey::windows::SettingsBackup::default_backup_filename();
    (void)skey::windows::SettingsBackup::export_to_file(vm_->settings(), destination);
}

void GeneralSettingsTab::OnImportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    // FileOpenPicker resolves the source (NSOpenPanel equivalent) and requires
    // the WinUI 3 runtime; feed the chosen path here.
    const auto source = std::filesystem::temp_directory_path() / "skey_backup.json";
    skey::windows::SettingsModel imported{};
    if (skey::windows::SettingsBackup::import_from_file(source, imported)) {
        vm_->apply(imported);
    }
}

void GeneralSettingsTab::OnFactoryResetClicked(winrt::Windows::Foundation::IInspectable const&,
                                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) vm_->factory_reset();
}

} // namespace winrt::SKey::Settings::implementation
#endif
