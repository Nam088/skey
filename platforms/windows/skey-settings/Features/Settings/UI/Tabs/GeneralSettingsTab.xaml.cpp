#include "pch.h"
#include "GeneralSettingsTab.xaml.h"
#if __has_include("GeneralSettingsTab.g.cpp")
#include "GeneralSettingsTab.g.cpp"
#endif
#if __has_include("GeneralSettingsTab.xaml.g.hpp")
#include "GeneralSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <windows.h>
#include <commdlg.h>
#pragma comment(lib, "comdlg32.lib")
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Windows.Storage.Pickers.h>

#include "../../../../Shared/Settings/Backup/SettingsBackup.h"
#include "../../../../ViewModels/SharedViewModel.h"
#include "../../../../Shared/Logging/AppLogger.h"
#include "../../../App/MainWindow.xaml.h"

namespace winrt::SKey::Settings::implementation {

GeneralSettingsTab::GeneralSettingsTab() {
    SKEY_LOG_INFO("GeneralSettingsTab() constructing...");
    try {
        vm_ = &skey::windows::shared_view_model();
        SKEY_LOG_INFO("shared_view_model resolved.");
    } catch (...) {
        SKEY_LOG_ERROR("Failed to resolve shared_view_model!");
    }
    InitializeComponent();
    SKEY_LOG_INFO("GeneralSettingsTab::InitializeComponent() succeeded.");
}

using namespace winrt::Microsoft::UI::Xaml::Controls;

void GeneralSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                      winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SKEY_LOG_INFO("GeneralSettingsTab::Page_Loaded() starting...");
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
    SKEY_LOG_INFO("GeneralSettingsTab::Page_Loaded() completed.");
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
    const auto theme = [&]() {
        switch (combo.SelectedIndex()) {
        case 1: return skey::windows::ThemeMode::light;
        case 2: return skey::windows::ThemeMode::dark;
        default: return skey::windows::ThemeMode::system;
        }
    }();
    vm_->set_theme(theme);
    MainWindow::ApplyTheme(theme);
}

void GeneralSettingsTab::OnDebugModeToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_debug_mode(toggle.IsOn());
}

void GeneralSettingsTab::OnExportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    wchar_t filename[MAX_PATH] = L"skey_settings_backup.json";
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = L"JSON Files (*.json)\0*.json\0All Files (*.*)\0*.*\0";
    ofn.lpstrFile = filename;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrTitle = L"Sao lưu cấu hình SKey";
    ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;
    ofn.lpstrDefExt = L"json";
    if (GetSaveFileNameW(&ofn)) {
        skey::windows::SettingsBackup::export_to_file(vm_->settings(), std::filesystem::path(filename));
    }
}

void GeneralSettingsTab::OnImportClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    wchar_t filename[MAX_PATH] = {0};
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = L"JSON Files (*.json)\0*.json\0All Files (*.*)\0*.*\0";
    ofn.lpstrFile = filename;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrTitle = L"Nhập cấu hình SKey từ file";
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    if (GetOpenFileNameW(&ofn)) {
        skey::windows::SettingsModel imported{};
        if (skey::windows::SettingsBackup::import_from_file(std::filesystem::path(filename), imported)) {
            vm_->apply(imported);
            Page_Loaded(nullptr, nullptr);
        }
    }
}

void GeneralSettingsTab::OnFactoryResetClicked(winrt::Windows::Foundation::IInspectable const&,
                                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (vm_) {
        vm_->factory_reset();
        Page_Loaded(nullptr, nullptr);
    }
}

} // namespace winrt::SKey::Settings::implementation
#endif
