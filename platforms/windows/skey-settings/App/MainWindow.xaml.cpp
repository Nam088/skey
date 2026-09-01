#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
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
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.Graphics.h>

#include <string_view>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Interop;

namespace {

// cppwinrt generates the winrt::xaml_typename<T>() helper only for the UWP
// Windows.UI.Xaml.Interop projection, so Frame.Navigate in a WinUI 3 app needs
// the Microsoft.UI.Xaml.Interop.TypeName built by hand. Going through
// name_of<T>() keeps this tied to the runtime class declared in Project.idl
// rather than a string literal that would rot silently.
template <typename T>
TypeName page_type() {
    return TypeName{winrt::hstring{winrt::name_of<T>()}, TypeKind::Metadata};
}

} // namespace

MainWindow::MainWindow() {
    InitializeComponent();
    // Microsoft.UI.Xaml.Window exposes no Width/Height; the initial size
    // has to go through AppWindow, which takes physical pixels.
    AppWindow().Resize({900, 680});
}

void MainWindow::NavigateForTag(winrt::hstring const& tag) {
    const auto view = std::wstring_view{tag};
    if (view == L"general") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::GeneralSettingsTab>());
    } else if (view == L"keyboard") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::KeyboardSettingsTab>());
    } else if (view == L"shortcuts") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::ShortcutsSettingsTab>());
    } else if (view == L"snippets") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::SnippetsSettingsTab>());
    } else if (view == L"clipboard") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::ClipboardSettingsTab>());
    } else if (view == L"tools") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::ToolsSettingsTab>());
    } else if (view == L"ai") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::AiSettingsTab>());
    } else if (view == L"appearance") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::AppearanceSettingsTab>());
    } else if (view == L"about") {
        ContentFrame().Navigate(page_type<winrt::SKey::Settings::AboutSettingsTab>());
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
