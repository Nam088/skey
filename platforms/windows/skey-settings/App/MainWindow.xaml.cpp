#include "MainWindow.xaml.h"

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>

namespace winrt::SKey::Settings::implementation {

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Media::Animation;

void MainWindow::InitNavigation() {
    if (initialized_) return;
    initialized_ = true;

    page_map_[L"general"] = {L"SKey.Settings.GeneralSettingsTab", TypeKind::Custom};
    page_map_[L"keyboard"] = {L"SKey.Settings.KeyboardSettingsTab", TypeKind::Custom};
    page_map_[L"shortcuts"] = {L"SKey.Settings.ShortcutsSettingsTab", TypeKind::Custom};
    page_map_[L"snippets"] = {L"SKey.Settings.SnippetsSettingsTab", TypeKind::Custom};
    page_map_[L"clipboard"] = {L"SKey.Settings.ClipboardSettingsTab", TypeKind::Custom};
    page_map_[L"tools"] = {L"SKey.Settings.ToolsSettingsTab", TypeKind::Custom};
    page_map_[L"ai"] = {L"SKey.Settings.AiSettingsTab", TypeKind::Custom};
    page_map_[L"appearance"] = {L"SKey.Settings.AppearanceSettingsTab", TypeKind::Custom};
    page_map_[L"about"] = {L"SKey.Settings.AboutSettingsTab", TypeKind::Custom};
}

void MainWindow::NavigateForTag(winrt::hstring const& tag) {
    InitNavigation();
    auto it = page_map_.find(std::wstring(tag));
    if (it != page_map_.end()) {
        ContentFrame().Navigate(it->second);
    }
}

void MainWindow::RootNavigation_SelectionChanged(NavigationView const& sender,
                                                  NavigationViewSelectionChangedEventArgs const& args) {
    auto item = args.SelectedItemContainer();
    if (!item) return;
    auto tag = winrt::unbox_value_or<winrt::hstring>(item.Tag(), L"");
    NavigateForTag(tag);
}

} // namespace winrt::SKey::Settings::implementation
#endif
