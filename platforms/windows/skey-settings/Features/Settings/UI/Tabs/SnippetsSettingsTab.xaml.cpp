#include "pch.h"
#include "SnippetsSettingsTab.xaml.h"
#if __has_include("SnippetsSettingsTab.g.cpp")
#include "SnippetsSettingsTab.g.cpp"
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

namespace winrt::SKey::Settings::implementation {

SnippetsSettingsTab::SnippetsSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
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
    const auto resource = Application::Current().Resources().TryLookup(winrt::box_value(key));
    return resource ? resource.as<Media::Brush>() : Media::Brush{nullptr};
}

ColumnDefinition column(GridUnitType type, double value) {
    ColumnDefinition definition;
    definition.Width(GridLengthHelper::FromValueAndType(value, type));
    return definition;
}

} // namespace

void SnippetsSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                      RoutedEventArgs const&) {
    if (!store_) {
        store_.emplace(skey::windows::SettingsPaths::macros_file());
    }
    if (vm_) {
        const auto& model = vm_->settings();
        syncing_ = true;
        EnableToggle().IsOn(model.macro_enabled);
        AutoCapsToggle().IsOn(model.macro_auto_caps);
        EnglishModeToggle().IsOn(model.macro_in_english_mode);
        syncing_ = false;
        MacroOptionsPanel().Visibility(model.macro_enabled ? Visibility::Visible : Visibility::Collapsed);
    }
    RefreshList();
}

void SnippetsSettingsTab::OnEnableToggled(ToggleSwitch const& sender, RoutedEventArgs const&) {
    if (!vm_ || syncing_) return;
    vm_->set_macro_enabled(sender.IsOn());
    MacroOptionsPanel().Visibility(sender.IsOn() ? Visibility::Visible : Visibility::Collapsed);
}

void SnippetsSettingsTab::OnAutoCapsToggled(ToggleSwitch const& sender, RoutedEventArgs const&) {
    if (vm_ && !syncing_) vm_->set_macro_auto_caps(sender.IsOn());
}

void SnippetsSettingsTab::OnEnglishModeToggled(ToggleSwitch const& sender, RoutedEventArgs const&) {
    if (vm_ && !syncing_) vm_->set_macro_in_english_mode(sender.IsOn());
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
    const auto entries = store_->load();

    ListTitle().Text(winrt::to_hstring("Snippets (" + std::to_string(entries.size()) + ")"));

    auto list = MacroListPanel();
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
    EmptyStateText().Visibility(shown == 0 ? Visibility::Visible : Visibility::Collapsed);
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
