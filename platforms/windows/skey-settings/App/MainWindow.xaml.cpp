#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
#endif
#if __has_include("MainWindow.xaml.g.hpp")
#include "MainWindow.xaml.g.hpp"
#endif

#ifdef _WIN32
#include "../Features/Settings/UI/Tabs/AboutSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/AiSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/AppearanceSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/ClipboardSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/GeneralSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/KeyboardSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/ShortcutsSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/SnippetsSettingsTab.xaml.h"
#include "../Features/Settings/UI/Tabs/ToolsSettingsTab.xaml.h"
#include "../../Shared/Logging/AppLogger.h"

#include <winrt/Microsoft.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.Graphics.h>

#include <string_view>

#include "../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Interop;

static MainWindow* s_current_main_window = nullptr;

void MainWindow::ApplyTheme(skey::windows::ThemeMode theme) {
    if (!s_current_main_window) return;
    try {
        auto grid = s_current_main_window->RootGrid();
        if (!grid) return;
        switch (theme) {
        case skey::windows::ThemeMode::light:
            grid.RequestedTheme(winrt::Microsoft::UI::Xaml::ElementTheme::Light);
            break;
        case skey::windows::ThemeMode::dark:
            grid.RequestedTheme(winrt::Microsoft::UI::Xaml::ElementTheme::Dark);
            break;
        default:
            grid.RequestedTheme(winrt::Microsoft::UI::Xaml::ElementTheme::Default);
            break;
        }
    } catch (...) {}
}

MainWindow::MainWindow() {
    s_current_main_window = this;
    SKEY_LOG_INFO("MainWindow() constructing...");
    InitializeComponent();
    SKEY_LOG_INFO("MainWindow::InitializeComponent() succeeded.");
    try {
        SystemBackdrop(winrt::Microsoft::UI::Xaml::Media::MicaBackdrop());
        SKEY_LOG_INFO("MicaBackdrop applied.");
    } catch (...) {
        SKEY_LOG_WARN("MicaBackdrop not supported or failed to apply.");
    }

    try {
        ApplyTheme(skey::windows::shared_view_model().settings().theme);
    } catch (...) {}

    // Microsoft.UI.Xaml.Window exposes no Width/Height; the initial size
    // has to go through AppWindow, which takes physical pixels.
    try {
        AppWindow().Resize({1020, 720});
    } catch (...) {}
    if (auto items = RootNavigation().MenuItems(); items.Size() > 0) {
        SKEY_LOG_INFO("Selecting first navigation item...");
        RootNavigation().SelectedItem(items.GetAt(0));
    } else {
        SKEY_LOG_INFO("Navigating directly to general tab...");
        NavigateForTag(L"general");
    }
}

void MainWindow::NavigateForTag(winrt::hstring const& tag) {
    try {
        const auto view = std::wstring_view{tag};
        std::string narrow_tag = winrt::to_string(tag);
        SKEY_LOG_INFO("Navigating to tab: " + narrow_tag);
        if (view == L"general") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::GeneralSettingsTab>());
        } else if (view == L"keyboard") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::KeyboardSettingsTab>());
        } else if (view == L"shortcuts") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::ShortcutsSettingsTab>());
        } else if (view == L"snippets") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::SnippetsSettingsTab>());
        } else if (view == L"clipboard") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::ClipboardSettingsTab>());
        } else if (view == L"tools") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::ToolsSettingsTab>());
        } else if (view == L"ai") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::AiSettingsTab>());
        } else if (view == L"appearance") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::AppearanceSettingsTab>());
        } else if (view == L"about") {
            ContentFrame().Navigate(winrt::xaml_typename<winrt::SKey::Settings::AboutSettingsTab>());
        }
    } catch (winrt::hresult_error const& ex) {
        MessageBoxW(nullptr, ex.message().c_str(), L"Navigation HRESULT Error", MB_ICONERROR);
    } catch (std::exception const& ex) {
        MessageBoxA(nullptr, ex.what(), "Navigation std Error", MB_ICONERROR);
    } catch (...) {
        MessageBoxW(nullptr, L"Unknown navigation error", L"Navigation Error", MB_ICONERROR);
    }
}

void MainWindow::RootNavigation_SelectionChanged(NavigationView const&,
                                                  NavigationViewSelectionChangedEventArgs const& args) {
    auto item = args.SelectedItemContainer();
    if (!item) return;
    NavigateForTag(winrt::unbox_value_or<winrt::hstring>(item.Tag(), L""));
}

} // namespace winrt::SKey::Settings::implementation
#endif
