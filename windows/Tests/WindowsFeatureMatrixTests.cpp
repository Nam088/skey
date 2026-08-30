#include "../Shared/Contracts/IpcCodec.h"
#include "../Shared/Localization/LocalizationService.h"
#include "../Shared/Settings/SettingsStore.h"
#include "../Shared/Theme/ThemeResolver.h"
#include "../skey-tray/TrayController.h"
#include "../skey-tray/TrayRuntime.h"

#include <cassert>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>

using namespace skey::windows;

int main() {
    // IPC matrix: round-trip every field, including delimiter characters.
    for (const auto& method : {std::string(kGetStatus), std::string(kSetLanguage),
                              std::string(kSetSettings), std::string(kResetEngine)}) {
        IpcRequest request{1, "request\t\n%", method, "payload\tline\n%\xE2\x9C\x93", 1};
        IpcRequest decoded;
        assert(IpcCodec::decode_request(IpcCodec::encode(request), decoded));
        assert(decoded.protocol_version == request.protocol_version);
        assert(decoded.request_id == request.request_id && decoded.method == request.method);
        assert(decoded.payload == request.payload && decoded.deadline_ms == request.deadline_ms);
    }
    for (const bool ok : {false, true}) {
        IpcResponse response{1, "response-1", ok, ok ? "" : "ERR_TIMEOUT", "result\nvalue"};
        IpcResponse decoded;
        assert(IpcCodec::decode_response(IpcCodec::encode(response), decoded));
        assert(decoded.ok == ok && decoded.error_code == response.error_code);
        assert(decoded.payload == response.payload);
    }

    // Tray state matrix: idempotent lifecycle and observable toggle callback.
    TrayController controller;
    assert(controller.start() && controller.is_running());
    controller.stop();
    assert(!controller.is_running());
    bool callback_value = false;
    TrayRuntime runtime([&callback_value](bool value) { callback_value = value; });
    assert(runtime.start() && runtime.running());
    assert(runtime.toggle_language() && !runtime.vietnamese_enabled() && !callback_value);
    runtime.stop();
    assert(!runtime.toggle_language());

    // Localization matrix: supported locales and deterministic missing-key fallback.
    LocalizationService localization(Locale::vi_vn);
    assert(localization.text("settings.general.title") == "Chung");
    assert(localization.text("missing.key") == "[missing translation]");
    localization.set_locale(Locale::en_us);
    assert(localization.text("settings.general.title") == "General");
    assert(localization.text("settings.theme.dark") == "Dark");

    // Theme matrix: explicit modes always win over the system mode.
    assert(ThemeResolver::resolve(ThemeMode::system, false) == ResolvedTheme::light);
    assert(ThemeResolver::resolve(ThemeMode::system, true) == ResolvedTheme::dark);
    assert(ThemeResolver::resolve(ThemeMode::light, true) == ResolvedTheme::light);
    assert(ThemeResolver::resolve(ThemeMode::dark, false) == ResolvedTheme::dark);

    // Storage matrix: persistence, defaults on missing/corrupt data, and reset.
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    const auto path = std::filesystem::temp_directory_path() / ("skey-feature-matrix-" + std::to_string(suffix) + ".json");
    SettingsStore store(path);
    const auto defaults = store.load();
    assert(defaults.locale == Locale::vi_vn && defaults.theme == ThemeMode::system);
    SettingsModel saved{};
    saved.schema_version = 7;
    saved.locale = Locale::en_us;
    saved.theme = ThemeMode::dark;
    saved.input_method = InputMethod::simple_telex;
    saved.charset = "unicode-cp1258";
    assert(store.save(saved));
    const auto loaded = store.load();
    assert(loaded.locale == saved.locale && loaded.theme == saved.theme);
    assert(loaded.input_method == saved.input_method && loaded.charset == saved.charset);
    {
        std::ofstream corrupt(path, std::ios::trunc);
        corrupt << "{\"locale\": \"invalid\", \"theme\": 42}";
    }
    const auto recovered = store.load();
    assert(recovered.locale == Locale::vi_vn && recovered.theme == ThemeMode::system);
    assert(store.reset() && !std::filesystem::exists(path));

    std::cout << "WINDOWS_FEATURE_MATRIX_OK\n";
}
