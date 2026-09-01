#include "pch.h"
#include "AiSettingsTab.xaml.h"
#if __has_include("AiSettingsTab.g.cpp")
#include "AiSettingsTab.g.cpp"
#endif

#ifdef _WIN32
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include <string>

#include "../../../../ViewModels/SharedViewModel.h"

namespace winrt::SKey::Settings::implementation {

AiSettingsTab::AiSettingsTab() {
    InitializeComponent();
    vm_ = &skey::windows::shared_view_model();
}

using namespace winrt::Microsoft::UI::Xaml::Controls;

namespace {

const char* provider_at(int index) {
    switch (index) {
    case 1: return "apple";
    case 2: return "gemini";
    case 3: return "deepl";
    case 4: return "groq";
    default: return "google";
    }
}

const char* language_at(int index) {
    switch (index) {
    case 1: return "en";
    case 2: return "ja";
    case 3: return "zh";
    case 4: return "ko";
    case 5: return "fr";
    case 6: return "de";
    default: return "vi";
    }
}

} // namespace

void AiSettingsTab::Page_Loaded(winrt::Windows::Foundation::IInspectable const&,
                                 winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_) return;
    loading_ = true;
    const auto& s = vm_->settings();

    const auto engine_index = [](const std::string& provider) {
        if (provider == "apple") return 1;
        if (provider == "gemini") return 2;
        if (provider == "deepl") return 3;
        if (provider == "groq") return 4;
        return 0;
    };
    PreferredEngineCombo().SelectedIndex(engine_index(s.translator_preferred_engine));

    const auto engine_for = [&s](const std::string& provider) -> const skey::windows::TranslatorEngine* {
        for (const auto& engine : s.translator_engines) {
            if (engine.provider == provider) return &engine;
        }
        return nullptr;
    };
    const auto engine_enabled = [&engine_for](const std::string& provider) {
        const auto* engine = engine_for(provider);
        return engine ? engine->enabled : true;
    };
    const auto engine_api_key = [&engine_for](const std::string& provider) {
        const auto* engine = engine_for(provider);
        return engine ? engine->api_key : std::string{};
    };

    PreferredEngineApiKeyBox().Password(winrt::to_hstring(engine_api_key(s.translator_preferred_engine)));

    const auto language_index = [](const std::string& language) {
        if (language == "en") return 1;
        if (language == "ja") return 2;
        if (language == "zh") return 3;
        if (language == "ko") return 4;
        if (language == "fr") return 5;
        if (language == "de") return 6;
        return 0;
    };
    TargetLanguageCombo().SelectedIndex(language_index(s.translator_target_language));
    AutoDetectToggle().IsOn(s.translator_auto_detect);

    EngineGoogleToggle().IsOn(engine_enabled("google"));
    EngineAppleToggle().IsOn(engine_enabled("apple"));
    EngineGeminiToggle().IsOn(engine_enabled("gemini"));
    EngineGeminiApiKeyBox().Password(winrt::to_hstring(engine_api_key("gemini")));
    EngineDeeplToggle().IsOn(engine_enabled("deepl"));
    EngineDeeplApiKeyBox().Password(winrt::to_hstring(engine_api_key("deepl")));
    EngineGroqToggle().IsOn(engine_enabled("groq"));
    EngineGroqApiKeyBox().Password(winrt::to_hstring(engine_api_key("groq")));
    loading_ = false;
}

void AiSettingsTab::OnPreferredEngineChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                              winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_translator_preferred_engine(provider_at(combo.SelectedIndex()));
}

void AiSettingsTab::OnPreferredEngineApiKeyChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                                    winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto box = sender.as<PasswordBox>();
    vm_->set_translator_api_key(vm_->settings().translator_preferred_engine, winrt::to_string(box.Password()));
}

void AiSettingsTab::OnTargetLanguageChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                             winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto combo = sender.as<ComboBox>();
    vm_->set_translator_target_language(language_at(combo.SelectedIndex()));
}

void AiSettingsTab::OnAutoDetectToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    vm_->set_translator_auto_detect(sender.IsOn());
}

void AiSettingsTab::OnEngineEnabledToggled(ToggleSwitch const& sender, winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    const auto provider = winrt::to_string(winrt::unbox_value<winrt::hstring>(sender.Tag()));
    vm_->set_translator_engine_enabled(provider, sender.IsOn());
}

void AiSettingsTab::OnEngineApiKeyChanged(winrt::Windows::Foundation::IInspectable const& sender,
                                           winrt::Microsoft::UI::Xaml::RoutedEventArgs const&) {
    if (!vm_ || loading_) return;
    auto box = sender.as<PasswordBox>();
    const auto provider = winrt::to_string(winrt::unbox_value<winrt::hstring>(box.Tag()));
    vm_->set_translator_api_key(provider, winrt::to_string(box.Password()));
}

} // namespace winrt::SKey::Settings::implementation
#endif
