#include "TrayRuntime.h"

#include <utility>

#ifdef _WIN32
#include <windows.h>

#include <chrono>

#include "../Shared/Clipboard/ClipboardText.h"
#include "../Shared/Settings/MacroStore.h"
#include "../Shared/Settings/SettingsPaths.h"
#include "../Shared/Settings/SettingsStore.h"
#include "Clipboard/ClipboardPaster.h"
#include "Clipboard/ClipboardPopup.h"
#include "Net/PlatformHttp.h"
#include "System/LaunchAtLogin.h"
#include "Translator/TranslationHud.h"
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

    if (clipboard_store_) clipboard_store_->set_max_items(settings.clipboard_max_items);
    if (clipboard_monitor_) {
        if (settings.clipboard_enabled && settings.clipboard_save_text) clipboard_monitor_->start();
        else clipboard_monitor_->stop();
    }

    LaunchAtLogin::set_enabled(settings.launch_at_login);
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
            case HotkeyAction::clipboard: open_clipboard_popup(); break;
            case HotkeyAction::cleaner:
                pipeline_->set_cleaner_active(!pipeline_->cleaner_active());
                break;
            case HotkeyAction::translate: open_translation_hud(); break;
            // AI lands in a later phase; swallow the chord for now so it
            // doesn't leak into the app.
            case HotkeyAction::ai: break;
            case HotkeyAction::none: break;
            }
        });
    pipeline_->set_excluded_app_provider([this] { return foreground_is_excluded(); });

    // Load persisted settings before the first event is processed.
    const SettingsModel model = SettingsStore{SettingsPaths::settings_file()}.load();
    settings_mtime_ = {};
    macros_mtime_ = {};
    reload_settings_if_changed();

    clipboard_store_ = std::make_unique<ClipboardHistoryStore>(SettingsPaths::clipboard_file());
    clipboard_store_->load();
    clipboard_monitor_ = std::make_unique<ClipboardMonitor>(
        [this](std::string text) { on_clipboard_capture(std::move(text)); });

    apply_settings(model);

    // The hook stays installed in English mode too: hotkeys (stage 5) and
    // English-mode macro expansion (stage 9) still need events.
    return hook_.install(
        [this](const HookKeyEvent& event) { return pipeline_->process(event); },
        [this] { pipeline_->on_mouse_click(); });
}

void TrayRuntime::stop_hook() {
    hook_.uninstall();
    clipboard_monitor_.reset();  // joins the poll thread before the store goes away
    clipboard_store_.reset();
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

void TrayRuntime::open_clipboard_popup() {
    if (!clipboard_popup_open_) {
        clipboard_popup_open_ = std::make_shared<std::atomic<bool>>(false);
    }
    bool expected = false;
    if (!clipboard_popup_open_->compare_exchange_strong(expected, true)) return;

    std::vector<ClipboardPopupItem> popup_items;
    {
        std::lock_guard<std::mutex> lock(clipboard_mutex_);
        if (clipboard_store_) {
            for (const auto& item : clipboard_store_->items()) {
                popup_items.push_back({item.text, item.folded, item.pinned});
            }
        }
    }
    if (popup_items.empty()) {
        clipboard_popup_open_->store(false);
        return;
    }

    // The hook callback thread must stay free (<5ms), so the modal popup
    // runs on its own thread. The flag keeps the thread alive independently
    // of TrayRuntime destruction.
    auto flag = clipboard_popup_open_;
    std::thread([items = std::move(popup_items), flag] {
        ClipboardPopup::show(items, [](std::string text) {
            ClipboardPaster::paste_text(text);
        });
        flag->store(false);
    }).detach();
}

void TrayRuntime::open_translation_hud() {
    if (!translation_hud_open_) {
        translation_hud_open_ = std::make_shared<std::atomic<bool>>(false);
    }
    bool expected = false;
    if (!translation_hud_open_->compare_exchange_strong(expected, true)) return;

    TranslationHudConfig config;
    {
        std::lock_guard<std::mutex> lock(settings_mutex_);
        config.engines = current_settings_.translator_engines;
        config.target_language = current_settings_.translator_target_language;
        config.auto_detect = current_settings_.translator_auto_detect;
    }

    auto flag = translation_hud_open_;
    std::thread([config = std::move(config), flag] {
        TranslationHud::show(config, make_platform_http());
        flag->store(false);
    }).detach();
}

void TrayRuntime::on_clipboard_capture(std::string text) {
    // Mirrors the macOS retention policy: whitespace-only and >10MB payloads
    // are not captured.
    constexpr std::size_t kMaxCaptureBytes = 10 * 1024 * 1024;
    if (text.size() > kMaxCaptureBytes || ClipboardText::is_blank(text)) return;

    const auto now = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch())
            .count());
    std::lock_guard<std::mutex> lock(clipboard_mutex_);
    if (!clipboard_store_) return;
    clipboard_store_->add_text(text, now);
    clipboard_store_->save();
}

#endif

} // namespace skey::windows
