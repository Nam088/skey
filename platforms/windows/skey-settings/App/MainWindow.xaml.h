#pragma once

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <unordered_map>
#include "../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct MainWindow {
    skey::windows::SettingsViewModel ViewModel{};

    void NavigateForTag(winrt::hstring const& tag);

private:
    void RootNavigation_SelectionChanged(winrt::Microsoft::UI::Xaml::Controls::NavigationView const& sender,
                                         winrt::Microsoft::UI::Xaml::Controls::NavigationViewSelectionChangedEventArgs const& args);
    void InitNavigation();

    std::unordered_map<std::wstring, winrt::Microsoft::UI::Xaml::Interop::TypeName> page_map_;
    bool initialized_{false};
};

} // namespace winrt::SKey::Settings::implementation
