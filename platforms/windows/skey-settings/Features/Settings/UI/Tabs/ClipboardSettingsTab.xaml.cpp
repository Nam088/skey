#include "pch.h"
#include "ClipboardSettingsTab.xaml.h"
#if __has_include("ClipboardSettingsTab.g.cpp")
#include "ClipboardSettingsTab.g.cpp"
#endif
#if __has_include("ClipboardSettingsTab.xaml.g.hpp")
#include "ClipboardSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

ClipboardSettingsTab::ClipboardSettingsTab() {
    vm_ = &skey::windows::shared_view_model();
    InitializeComponent();
}

using namespace winrt::Microsoft::UI::Xaml::Controls;

void ClipboardSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                        winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    loading_ = true;
    const auto& s = vm_->settings();

    EnableToggle().IsOn(s.clipboard_enabled);
    SearchModeCombo().SelectedIndex(s.clipboard_search_mode == "Exact" ? 1 : 0);
    AutoPasteToggle().IsOn(s.clipboard_auto_paste);
    PastePlainTextToggle().IsOn(s.clipboard_paste_plain_text);
    SaveTextToggle().IsOn(s.clipboard_save_text);
    SaveImagesToggle().IsOn(s.clipboard_save_images);
    MaxItemsSlider().Value(static_cast<double>(s.clipboard_max_items));

    const auto sort_index = [](skey::windows::ClipboardSortOrder order) {
        switch (order) {
        case skey::windows::ClipboardSortOrder::first_copied_at: return 1;
        case skey::windows::ClipboardSortOrder::number_of_copies: return 2;
        default: return 0;
        }
    };
    SortOrderCombo().SelectedIndex(sort_index(s.clipboard_sort_order));

    const auto popup_position_index = [](skey::windows::ClipboardPopupPosition position) {
        switch (position) {
        case skey::windows::ClipboardPopupPosition::status_item: return 1;
        default: return 0;
        }
    };
    PopupPositionCombo().SelectedIndex(popup_position_index(s.clipboard_popup_position));

    const auto pin_to_index = [](skey::windows::ClipboardPinTo pin_to) {
        switch (pin_to) {
        case skey::windows::ClipboardPinTo::bottom: return 1;
        default: return 0;
        }
    };
    PinToCombo().SelectedIndex(pin_to_index(s.clipboard_pin_to));

    ThumbHeightSlider().Value(static_cast<double>(s.clipboard_image_thumb_height));
    HoverPreviewToggle().IsOn(s.clipboard_open_preview_auto);
    ShowAppIconsToggle().IsOn(s.clipboard_show_app_icons);
    ShowHexSwatchToggle().IsOn(s.clipboard_show_hex_color_swatch);
    loading_ = false;
}

void ClipboardSettingsTab::OnEnableToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_enabled(toggle.IsOn());
}

void ClipboardSettingsTab::OnSearchModeChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_clipboard_search_mode(combo.SelectedIndex() == 0 ? "Fuzzy" : "Exact");
}

void ClipboardSettingsTab::OnAutoPasteToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_auto_paste(toggle.IsOn());
}

void ClipboardSettingsTab::OnPastePlainTextToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_paste_plain_text(toggle.IsOn());
}

void ClipboardSettingsTab::OnSaveTextToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_save_text(toggle.IsOn());
}

void ClipboardSettingsTab::OnSaveImagesToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_save_images(toggle.IsOn());
}

void ClipboardSettingsTab::OnMaxItemsChanged(winrt::Windows::Foundation::IInspectable const& sender, Primitives::RangeBaseValueChangedEventArgs const&) {
    const auto slider = sender.as<Slider>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_max_items(static_cast<std::size_t>(slider.Value()));
}

void ClipboardSettingsTab::OnSortOrderChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                               winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    switch (combo.SelectedIndex()) {
    case 1: vm_->set_clipboard_sort_order(skey::windows::ClipboardSortOrder::first_copied_at); break;
    case 2: vm_->set_clipboard_sort_order(skey::windows::ClipboardSortOrder::number_of_copies); break;
    default: vm_->set_clipboard_sort_order(skey::windows::ClipboardSortOrder::last_copied_at); break;
    }
}

void ClipboardSettingsTab::OnClearHistoryClicked(winrt::Windows::Foundation::IInspectable const&,
                                                  winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    // Clear clipboard history via ClipboardService - requires the WinUI 3 runtime host.
}

void ClipboardSettingsTab::OnPopupPositionChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                   winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_clipboard_popup_position(combo.SelectedIndex() == 0
        ? skey::windows::ClipboardPopupPosition::cursor
        : skey::windows::ClipboardPopupPosition::status_item);
}

void ClipboardSettingsTab::OnPinToChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                           winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_clipboard_pin_to(combo.SelectedIndex() == 0
        ? skey::windows::ClipboardPinTo::top
        : skey::windows::ClipboardPinTo::bottom);
}

void ClipboardSettingsTab::OnThumbHeightChanged(winrt::Windows::Foundation::IInspectable const& sender, Primitives::RangeBaseValueChangedEventArgs const&) {
    const auto slider = sender.as<Slider>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_image_thumb_height(static_cast<std::size_t>(slider.Value()));
}

void ClipboardSettingsTab::OnHoverPreviewToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_open_preview_auto(toggle.IsOn());
}

void ClipboardSettingsTab::OnShowAppIconsToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_show_app_icons(toggle.IsOn());
}

void ClipboardSettingsTab::OnShowHexSwatchToggled(winrt::Windows::Foundation::IInspectable const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || loading_) return;
    vm_->set_clipboard_show_hex_color_swatch(toggle.IsOn());
}

} // namespace winrt::SKey::Settings::implementation
#endif
