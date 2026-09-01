#pragma once

#include "ClipboardSettingsTab.g.h"

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include "../../../../ViewModels/SettingsViewModel.h"

namespace winrt::SKey::Settings::implementation {

struct ClipboardSettingsTab : ClipboardSettingsTabT<ClipboardSettingsTab> {
    ClipboardSettingsTab();
    void Page_Loaded(winrt::Windows::Foundation::IInspectable const& sender,
                     winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    void OnEnableToggled(winrt::Windows::Foundation::IInspectable const& sender,
                         winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSearchModeChanged(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnAutoPasteToggled(winrt::Windows::Foundation::IInspectable const& sender,
                            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnPastePlainTextToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSaveTextToggled(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnSaveImagesToggled(winrt::Windows::Foundation::IInspectable const& sender,
                             winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnMaxItemsChanged(winrt::Windows::Foundation::IInspectable const& sender,
                           winrt::Microsoft::UI::Xaml::Controls::Primitives::RangeBaseValueChangedEventArgs const& args);
    void OnSortOrderChanged(winrt::Windows::Foundation::IInspectable const& sender,
                            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnClearHistoryClicked(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnPopupPositionChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnPinToChanged(winrt::Windows::Foundation::IInspectable const& sender,
                        winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& args);
    void OnThumbHeightChanged(winrt::Windows::Foundation::IInspectable const& sender,
                              winrt::Microsoft::UI::Xaml::Controls::Primitives::RangeBaseValueChangedEventArgs const& args);
    void OnHoverPreviewToggled(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnShowAppIconsToggled(winrt::Windows::Foundation::IInspectable const& sender,
                               winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);
    void OnShowHexSwatchToggled(winrt::Windows::Foundation::IInspectable const& sender,
                                winrt::Microsoft::UI::Xaml::RoutedEventArgs const& args);

    skey::windows::SettingsViewModel* vm_{nullptr};
    bool loading_{true};
};

} // namespace winrt::SKey::Settings::implementation

namespace winrt::SKey::Settings::factory_implementation {
struct ClipboardSettingsTab : ClipboardSettingsTabT<ClipboardSettingsTab, implementation::ClipboardSettingsTab> {};
} // namespace winrt::SKey::Settings::factory_implementation
