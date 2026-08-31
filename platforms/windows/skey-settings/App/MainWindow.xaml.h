#pragma once

#include "MainWindow.xaml.g.h"

namespace winrt::SKey::Settings::implementation {

struct MainWindow : MainWindowT<MainWindow> {
    MainWindow();

    void NavigateForTag(winrt::hstring const& tag);

    void RootNavigation_SelectionChanged(winrt::Microsoft::UI::Xaml::Controls::NavigationView const& sender,
                                         winrt::Microsoft::UI::Xaml::Controls::NavigationViewSelectionChangedEventArgs const& args);
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow> {};
} // namespace winrt::SKey::Settings::factory_implementation
