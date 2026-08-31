#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.xaml.g.cpp")
#include "MainWindow.xaml.g.cpp"
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

#include <winrt/Microsoft.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>

#include <string_view>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Interop;

MainWindow::MainWindow() {
    InitializeComponent();
}

void MainWindow::NavigateForTag(winrt::hstring const& tag) {
    const auto view = std::wstring_view{tag};
    if (view == L"general") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::GeneralSettingsTab>());
    } else if (view == L"keyboard") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::KeyboardSettingsTab>());
    } else if (view == L"shortcuts") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::ShortcutsSettingsTab>());
    } else if (view == L"snippets") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::SnippetsSettingsTab>());
    } else if (view == L"clipboard") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::ClipboardSettingsTab>());
    } else if (view == L"tools") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::ToolsSettingsTab>());
    } else if (view == L"ai") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::AiSettingsTab>());
    } else if (view == L"appearance") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::AppearanceSettingsTab>());
    } else if (view == L"about") {
        ContentFrame().Navigate(xaml_typename<winrt::SKey::Settings::AboutSettingsTab>());
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
