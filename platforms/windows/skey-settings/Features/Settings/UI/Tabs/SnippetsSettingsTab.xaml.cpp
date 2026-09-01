#include "pch.h"
#include "SnippetsSettingsTab.xaml.h"
#if __has_include("SnippetsSettingsTab.g.cpp")
#include "SnippetsSettingsTab.g.cpp"
#endif
#if __has_include("SnippetsSettingsTab.xaml.g.hpp")
#include "SnippetsSettingsTab.xaml.g.hpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Windows.Storage.h>

#include <algorithm>
#include <filesystem>

#include "../../../../../Shared/Settings/SettingsPaths.h"
#include "../../../../ViewModels/SharedViewModel.h"
#include "../../../../Shared/Logging/AppLogger.h"

namespace winrt::SKey::Settings::implementation {

SnippetsSettingsTab::SnippetsSettingsTab() {
    SKEY_LOG_INFO("SnippetsSettingsTab() constructing...");
    syncing_ = true;
    try {
        vm_ = &skey::windows::shared_view_model();
    } catch (...) {}
    InitializeComponent();
    SKEY_LOG_INFO("SnippetsSettingsTab::InitializeComponent() succeeded.");
}

using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;

namespace {

std::string to_utf8(winrt::hstring const& text) {
    return winrt::to_string(text);
}

std::string trimmed(const std::string& text) {
    const char* ws = " \t\n\r";
    const auto first = text.find_first_not_of(ws);
    if (first == std::string::npos) return {};
    const auto last = text.find_last_not_of(ws);
    return text.substr(first, last - first + 1);
}

std::string lowercased(std::string text) {
    std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) {
        return static_cast<char>((c >= 'A' && c <= 'Z') ? c - 'A' + 'a' : c);
    });
    return text;
}

bool contains_ci(const std::string& haystack, const std::string& needle) {
    return lowercased(haystack).find(lowercased(needle)) != std::string::npos;
}

Media::Brush theme_brush(const wchar_t* key) {
    try {
        const auto resource = Application::Current().Resources().TryLookup(winrt::box_value(key));
        if (resource) return resource.as<Media::Brush>();
    } catch (...) {}
    return Media::SolidColorBrush{Windows::UI::Color{0, 0, 0, 0}};
}

ColumnDefinition column(GridUnitType type, double value) {
    ColumnDefinition definition;
    definition.Width(winrt::Microsoft::UI::Xaml::GridLength{value, type});
    return definition;
}

} // namespace

void SnippetsSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                      RoutedEventArgs const&) {
    SKEY_LOG_INFO("SnippetsSettingsTab::Page_Loaded() starting...");
    if (!store_) {
        try {
            store_.emplace(skey::windows::SettingsPaths::macros_file());
        } catch (...) {}
    }
    if (vm_) {
        const auto& model = vm_->settings();
        syncing_ = true;
        EnableToggle().IsOn(model.macro_enabled);
        AutoCapsToggle().IsOn(model.macro_auto_caps);
        EnglishModeToggle().IsOn(model.macro_in_english_mode);
        if (auto panel = MacroOptionsPanel()) {
            panel.Visibility(model.macro_enabled ? Visibility::Visible : Visibility::Collapsed);
        }
        syncing_ = false;
    }
    RefreshList();
    SKEY_LOG_INFO("SnippetsSettingsTab::Page_Loaded() completed.");
}

void SnippetsSettingsTab::OnEnableToggled(winrt::Windows::Foundation::IInspectable const& sender, RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (!vm_ || syncing_) return;
    vm_->set_macro_enabled(toggle.IsOn());
    if (auto panel = MacroOptionsPanel()) {
        panel.Visibility(toggle.IsOn() ? Visibility::Visible : Visibility::Collapsed);
    }
}

void SnippetsSettingsTab::OnAutoCapsToggled(winrt::Windows::Foundation::IInspectable const& sender, RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (vm_ && !syncing_) vm_->set_macro_auto_caps(toggle.IsOn());
}

void SnippetsSettingsTab::OnEnglishModeToggled(winrt::Windows::Foundation::IInspectable const& sender, RoutedEventArgs const&) {
    const auto toggle = sender.as<ToggleSwitch>();
    if (vm_ && !syncing_) vm_->set_macro_in_english_mode(toggle.IsOn());
}

void SnippetsSettingsTab::OnAddFieldChanged(winrt::Windows::Foundation::IInspectable const&,
                                            TextChangedEventArgs const&) {
    const auto trigger_ok = !trimmed(to_utf8(NewTriggerBox().Text())).empty();
    const auto replacement_ok = !trimmed(to_utf8(NewReplacementBox().Text())).empty();
    AddButton().IsEnabled(trigger_ok && replacement_ok);
}

void SnippetsSettingsTab::OnAddClicked(winrt::Windows::Foundation::IInspectable const&,
                                       RoutedEventArgs const&) {
    if (!store_) return;
    if (!store_->add(to_utf8(NewTriggerBox().Text()), to_utf8(NewReplacementBox().Text()))) return;
    NewTriggerBox().Text(L"");
    NewReplacementBox().Text(L"");
    AddButton().IsEnabled(false);
    RefreshList();
}

void SnippetsSettingsTab::OnSearchChanged(winrt::Windows::Foundation::IInspectable const&,
                                          TextChangedEventArgs const&) {
    search_text_ = to_utf8(SearchBox().Text());
    RefreshList();
}

void SnippetsSettingsTab::RefreshList() {
    if (!store_) return;
    try {
        const auto entries = store_->load();

        if (auto title = ListTitle()) {
            title.Text(winrt::to_hstring("Danh sách từ gõ tắt (" + std::to_string(entries.size()) + ")"));
        }

        auto list = MacroListPanel();
        if (!list) return;
        list.Children().Clear();

        const auto query = lowercased(trimmed(search_text_));
        std::size_t shown = 0;
        for (const auto& entry : entries) {
            if (!query.empty() && !contains_ci(entry.trigger, query) && !contains_ci(entry.replacement, query)) {
                continue;
            }
            if (shown > 0) {
                Border divider;
                divider.Height(1);
                divider.Margin(Thickness{14, 4, 0, 4});
                divider.Background(theme_brush(L"DividerStrokeColorDefaultBrush"));
                list.Children().Append(divider);
            }
            list.Children().Append(BuildRow(entry));
            ++shown;
        }
        if (auto empty = EmptyStateText()) {
            empty.Visibility(shown == 0 ? Visibility::Visible : Visibility::Collapsed);
        }
    } catch (std::exception const& ex) {
        SKEY_LOG_ERROR(std::string("RefreshList exception: ") + ex.what());
    } catch (...) {
        SKEY_LOG_ERROR("RefreshList unknown exception");
    }
}

UIElement SnippetsSettingsTab::BuildRow(const skey::windows::MacroEntry& entry) {
    if (editing_trigger_ && *editing_trigger_ == entry.trigger) return BuildEditRow(entry);

    Grid row;
    row.ColumnSpacing(12);
    row.Margin(Thickness{0, 8, 0, 8});
    row.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));
    row.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));
    row.ColumnDefinitions().Append(column(GridUnitType::Star, 1));
    row.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));

    Border badge;
    badge.CornerRadius(winrt::Microsoft::UI::Xaml::CornerRadius{4, 4, 4, 4});
    badge.Padding(Thickness{8, 3, 8, 3});
    badge.VerticalAlignment(VerticalAlignment::Top);
    badge.Background(theme_brush(L"ControlFillColorDefaultBrush"));
    TextBlock trigger;
    trigger.Text(winrt::to_hstring(entry.trigger));
    trigger.FontFamily(Media::FontFamily(L"Consolas"));
    badge.Child(trigger);
    Grid::SetColumn(badge, 0);
    row.Children().Append(badge);

    FontIcon arrow;
    arrow.Glyph(L"\uE76C");
    arrow.FontSize(11);
    arrow.VerticalAlignment(VerticalAlignment::Top);
    arrow.Foreground(theme_brush(L"TextFillColorSecondaryBrush"));
    Grid::SetColumn(arrow, 1);
    row.Children().Append(arrow);

    TextBlock replacement;
    replacement.Text(winrt::to_hstring(entry.replacement));
    replacement.TextWrapping(TextWrapping::Wrap);
    replacement.MaxLines(4);
    Grid::SetColumn(replacement, 2);
    row.Children().Append(replacement);

    StackPanel actions;
    actions.Orientation(Orientation::Horizontal);
    actions.Spacing(6);
    actions.VerticalAlignment(VerticalAlignment::Top);

    Button edit;
    edit.Content(SymbolIcon(Symbol::Edit));
    edit.Click([this, trigger_key = entry.trigger](winrt::Windows::Foundation::IInspectable const&,
                                                   RoutedEventArgs const&) {
        editing_trigger_ = trigger_key;
        RefreshList();
    });
    actions.Children().Append(edit);

    Button remove;
    remove.Content(SymbolIcon(Symbol::Delete));
    remove.Click([this, trigger_key = entry.trigger](winrt::Windows::Foundation::IInspectable const&,
                                                     RoutedEventArgs const&) {
        if (store_) {
            store_->remove(trigger_key);
            RefreshList();
        }
    });
    actions.Children().Append(remove);

    Grid::SetColumn(actions, 3);
    row.Children().Append(actions);
    return row;
}

UIElement SnippetsSettingsTab::BuildEditRow(const skey::windows::MacroEntry& entry) {
    StackPanel panel;
    panel.Spacing(8);
    panel.Margin(Thickness{0, 8, 0, 8});

    Grid top;
    top.ColumnSpacing(10);
    top.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));
    top.ColumnDefinitions().Append(column(GridUnitType::Star, 1));
    top.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));
    top.ColumnDefinitions().Append(column(GridUnitType::Auto, 0));

    TextBox trigger_box;
    trigger_box.Text(winrt::to_hstring(entry.trigger));
    trigger_box.Width(160);
    Grid::SetColumn(trigger_box, 0);
    top.Children().Append(trigger_box);

    TextBox replacement_box;
    replacement_box.Text(winrt::to_hstring(entry.replacement));
    replacement_box.AcceptsReturn(true);
    replacement_box.TextWrapping(TextWrapping::Wrap);
    replacement_box.MinHeight(60);

    Button save;
    save.Content(winrt::box_value(L"Save"));
    save.Click([this, trigger_box, replacement_box](winrt::Windows::Foundation::IInspectable const&,
                                                    RoutedEventArgs const&) {
        if (store_ && editing_trigger_ &&
            !store_->update(*editing_trigger_, to_utf8(trigger_box.Text()), to_utf8(replacement_box.Text()))) {
            return;
        }
        editing_trigger_.reset();
        RefreshList();
    });
    Grid::SetColumn(save, 2);
    top.Children().Append(save);

    Button cancel;
    cancel.Content(winrt::box_value(L"Cancel"));
    cancel.Click([this](winrt::Windows::Foundation::IInspectable const&, RoutedEventArgs const&) {
        editing_trigger_.reset();
        RefreshList();
    });
    Grid::SetColumn(cancel, 3);
    top.Children().Append(cancel);

    panel.Children().Append(top);
    panel.Children().Append(replacement_box);
    return panel;
}

} // namespace winrt::SKey::Settings::implementation
#endif
