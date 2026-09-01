#include "pch.h"
#include "ToolsSettingsTab.xaml.h"
#if __has_include("ToolsSettingsTab.g.cpp")
#include "ToolsSettingsTab.g.cpp"
#endif
#if __has_include("ToolsSettingsTab.xaml.g.hpp")
#include "ToolsSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../ViewModels/SharedViewModel.h"
#include "../../../../Shared/Logging/AppLogger.h"

namespace winrt::SKey::Settings::implementation {

ToolsSettingsTab::ToolsSettingsTab() {
    SKEY_LOG_INFO("ToolsSettingsTab() constructing...");
    loading_ = true;
    try {
        vm_ = &skey::windows::shared_view_model();
    } catch (...) {}
    InitializeComponent();
    SKEY_LOG_INFO("ToolsSettingsTab::InitializeComponent() succeeded.");
}

using namespace winrt::Microsoft::UI::Xaml::Controls;

void ToolsSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    SKEY_LOG_INFO("ToolsSettingsTab::Page_Loaded() starting...");
    if (!vm_) return;
    loading_ = true;
    try {
        const auto& s = vm_->settings();
        if (auto toggle = CleanerEnabledToggle()) {
            toggle.IsOn(s.cleaner_enabled);
        }
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("ToolsSettingsTab::Page_Loaded exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("ToolsSettingsTab::Page_Loaded unknown exception");
    }
    loading_ = false;
    SKEY_LOG_INFO("ToolsSettingsTab::Page_Loaded() completed.");
}

void ToolsSettingsTab::OnCleanerEnabledToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_cleaner_enabled(toggle.IsOn());
}

void ToolsSettingsTab::OnCleanNowClicked(winrt::Windows::Foundation::IInspectable const&,
                                          winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // Launches the Cleaner page (KeyboardCleanerController.startCleaning equivalent),
    // which requires the WinUI 3 runtime host.
}

void ToolsSettingsTab::OnQuickTransformClicked(winrt::Windows::Foundation::IInspectable const& sender,
                                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    auto button = sender.as<Button>();
    const auto action = winrt::to_string(winrt::unbox_value<winrt::hstring>(button.Tag()));
    (void)action;
    // TextTransformService (encoding/case transforms on the clipboard text) is not
    // available on Windows yet; dispatch on `action` once it lands.
}

void ToolsSettingsTab::OnConvertClicked(winrt::Windows::Foundation::IInspectable const&,
                                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // TextTransformService (tcvn3/vni <-> unicode conversion) is not available on
    // Windows yet; read ConverterSourceCombo/ConverterTargetCombo/ConverterInputBox then.
}

} // namespace winrt::SKey::Settings::implementation
#endif
