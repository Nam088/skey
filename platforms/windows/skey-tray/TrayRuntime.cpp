#include "TrayRuntime.h"

#include <utility>

#ifdef _WIN32
#include <windows.h>

#include "../Shared/Settings/MacroStore.h"
#include "../Shared/Settings/SettingsPaths.h"
#include "../Shared/Settings/SettingsStore.h"
#endif

namespace skey::windows {

TrayRuntime::TrayRuntime(StatusCallback callback) : callback_(std::move(callback)) {}
TrayRuntime::~TrayRuntime() { stop(); }

bool TrayRuntime::start() {
    bool expected = false;
    if (!running_.compare_exchange_strong(expected, true)) return false;
#ifdef _WIN32
    // Hook failure is non-fatal: tray + IPC still run in degraded mode.
    start_hook();
#endif
    service_thread_ = std::thread(&TrayRuntime::service_loop, this);
    return true;
}

void TrayRuntime::stop() {
    if (!running_.exchange(false)) return;
#ifdef _WIN32
    stop_hook();
#endif
    if (service_thread_.joinable()) service_thread_.join();
    if (ipc_thread_.joinable()) ipc_thread_.join();
}

bool TrayRuntime::start_ipc(IpcHandler handler, std::string endpoint) {
    if (!handler || !start()) return false;
    ipc_thread_ = std::thread([this, handler = std::move(handler), endpoint = std::move(endpoint)] {
        IpcServer server(handler);
#ifdef _WIN32
        while (running_.load()) server.serve_once(endpoint);
#else
        (void)server; (void)endpoint;
        // Named pipes are Windows-only; lifecycle remains testable elsewhere.
        while (running_.load()) std::this_thread::yield();
#endif
    });
    return true;
}

bool TrayRuntime::toggle_language() {
    if (!running()) return false;
    set_language(!vietnamese_enabled_.load());
    return true;
}

void TrayRuntime::set_language(bool vietnamese) {
    if (vietnamese_enabled_.exchange(vietnamese) == vietnamese) return;
#ifdef _WIN32
    if (pipeline_) {
        auto config = pipeline_->config();
        config.vietnamese = vietnamese;
        pipeline_->set_config(config);
    }
    if (engine_) engine_->reset();
    macro_.reset();
#endif
    if (callback_) callback_(vietnamese);
}

void TrayRuntime::apply_settings(const SettingsModel& settings) {
#ifdef _WIN32
    {
        std::lock_guard<std::mutex> lock(settings_mutex_);
        current_settings_ = settings;
    }

    if (engine_) {
        switch (settings.input_method) {
        case InputMethod::telex: engine_->set_input_method(EngineInputMethod::telex); break;
        case InputMethod::vni: engine_->set_input_method(EngineInputMethod::vni); break;
        case InputMethod::viqr: engine_->set_input_method(EngineInputMethod::viqr); break;
        case InputMethod::simple_telex: engine_->set_input_method(EngineInputMethod::simple_telex); break;
        }
        engine_->set_spell_check(settings.spell_check);
        engine_->set_modern_style(settings.modern_style);
        engine_->set_free_marking(settings.free_marking);
        engine_->set_swallowed_key_restore(settings.swallowed_key_restore);
        engine_->set_quick_telex(settings.quick_telex);
        engine_->set_quick_start_consonant(settings.quick_start_consonant);
        engine_->set_quick_end_consonant(settings.quick_end_consonant);
        engine_->set_upper_case_first_char(settings.upper_case_first_char);
        engine_->set_allow_consonant_zfwj(settings.allow_consonant_zfwj);
        engine_->reset();
    }

    macro_.reload(MacroStore{SettingsPaths::macros_file()}.entries_as_pairs());
    macro_.set_enabled(settings.macro_enabled);
    macro_.set_auto_caps(settings.macro_auto_caps);

    if (pipeline_) {
        pipeline_->hotkeys().apply_records(settings.hotkeys);
        pipeline_->hotkeys().set_cleaner_enabled(settings.cleaner_enabled);

        TypingPipeline::Config config = pipeline_->config();
        config.vietnamese = settings.is_vietnamese;
        config.macro_enabled = settings.macro_enabled;
        config.macro_in_english = settings.macro_in_english_mode;
        config.cleaner_enabled = settings.cleaner_enabled;
        config.restore_enabled = settings.swallowed_key_restore;
        pipeline_->set_config(config);
    }

    // Settings file is the source of truth on (re)load; runtime hotkey
    // toggles only diverge until the next save.
    vietnamese_enabled_.store(settings.is_vietnamese);
    if (callback_) callback_(settings.is_vietnamese);
#else
    (void)settings;
#endif
}

void TrayRuntime::service_loop() {
#ifdef _WIN32
    // The native message loop is owned by TrayApp; this thread watches the
    // settings files and the foreground app.
    int tick = 0;
    while (running_.load()) {
        ::Sleep(250);
        ++tick;
        update_smart_app_switch();
        if (tick % 8 == 0) reload_settings_if_changed();  // ~2s
    }
#else
    // Portable test lifecycle: no platform loop is required.
    while (running_.load()) std::this_thread::sleep_for(std::chrono::milliseconds(25));
#endif
}

#ifdef _WIN32

bool TrayRuntime::start_hook() {
    engine_ = std::make_unique<SKeyEngineWrapper>();
    pipeline_ = std::make_unique<TypingPipeline>(
        *engine_, macro_, [this](HotkeyAction action) {
            switch (action) {
            case HotkeyAction::toggle_language: toggle_language(); break;
            // Clipboard popup / cleaner / AI / translate land in Phases 3-4;
            // swallow the chord for now so it doesn't leak into the app.
            case HotkeyAction::clipboard:
            case HotkeyAction::cleaner:
            case HotkeyAction::ai:
            case HotkeyAction::translate: break;
            case HotkeyAction::none: break;
            }
        });
    pipeline_->set_excluded_app_provider([this] { return foreground_is_excluded(); });

    // Load persisted settings before the first event is processed.
    const SettingsModel model = SettingsStore{SettingsPaths::settings_file()}.load();
    settings_mtime_ = {};
    macros_mtime_ = {};
    reload_settings_if_changed();
    apply_settings(model);

    // The hook stays installed in English mode too: hotkeys (stage 5) and
    // English-mode macro expansion (stage 9) still need events.
    return hook_.install(
        [this](const HookKeyEvent& event) { return pipeline_->process(event); },
        [this] { pipeline_->on_mouse_click(); });
}

void TrayRuntime::stop_hook() {
    hook_.uninstall();
    pipeline_.reset();
    engine_.reset();
}

void TrayRuntime::reload_settings_if_changed() {
    std::error_code ec;
    const auto settings_path = SettingsPaths::settings_file();
    const auto macros_path = SettingsPaths::macros_file();

    const auto settings_time = std::filesystem::last_write_time(settings_path, ec);
    const bool settings_changed = !ec && settings_time != settings_mtime_;
    std::filesystem::file_time_type macros_time{};
    bool macros_changed = false;
    if (std::filesystem::exists(macros_path, ec) && !ec) {
        macros_time = std::filesystem::last_write_time(macros_path, ec);
        macros_changed = !ec && macros_time != macros_mtime_;
    }

    if (settings_changed) {
        settings_mtime_ = settings_time;
        apply_settings(SettingsStore{settings_path}.load());
    } else if (macros_changed) {
        macros_mtime_ = macros_time;
        SettingsModel snapshot;
        {
            std::lock_guard<std::mutex> lock(settings_mutex_);
            snapshot = current_settings_;
        }
        macro_.reload(MacroStore{macros_path}.entries_as_pairs());
        macro_.set_enabled(snapshot.macro_enabled);
        macro_.set_auto_caps(snapshot.macro_auto_caps);
    } else {
        // First run: remember mtimes without applying twice.
        if (settings_mtime_ == std::filesystem::file_time_type{} && !ec) {
            settings_mtime_ = settings_time;
        }
        if (macros_mtime_ == std::filesystem::file_time_type{} && macros_time != std::filesystem::file_time_type{}) {
            macros_mtime_ = macros_time;
        }
    }
}

bool TrayRuntime::foreground_is_excluded() {
    SettingsModel snapshot;
    {
        std::lock_guard<std::mutex> lock(settings_mutex_);
        snapshot = current_settings_;
    }
    if (!snapshot.app_exclusion_enabled || snapshot.excluded_apps.empty()) return false;
    return ForegroundAppTracker::is_excluded(app_tracker_.current_exe(), snapshot.excluded_apps);
}

void TrayRuntime::update_smart_app_switch() {
    SettingsModel snapshot;
    {
        std::lock_guard<std::mutex> lock(settings_mutex_);
        snapshot = current_settings_;
    }

    const std::string exe = app_tracker_.current_exe();
    if (exe == last_foreground_exe_) return;
    last_foreground_exe_ = exe;

    if (!snapshot.smart_app_switch) {
        if (smart_switch_active_) {
            smart_switch_active_ = false;
            set_language(true);
        }
        return;
    }

    // Mirrors macOS KeyboardFeature.handleAppFocusChanged: developer tools
    // force English, leaving them restores Vietnamese.
    if (ForegroundAppTracker::is_developer_tool(exe)) {
        if (vietnamese_enabled()) {
            smart_switch_active_ = true;
            set_language(false);
        }
    } else if (smart_switch_active_) {
        smart_switch_active_ = false;
        set_language(true);
    }
}

#endif

} // namespace skey::windows
