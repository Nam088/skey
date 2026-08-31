#include "TrayRuntime.h"

#include <utility>

#ifdef _WIN32
#include <windows.h>

#include <chrono>

#include "../Shared/Clipboard/ClipboardText.h"
#include "../Shared/Localization/LocalizationService.h"
#include "../Shared/Settings/MacroStore.h"
#include "../Shared/Settings/SettingsPaths.h"
#include "../Shared/Settings/SettingsStore.h"
#include "Clipboard/ClipboardPaster.h"
#include "Clipboard/ClipboardPopup.h"
#include "Net/PlatformHttp.h"
#include "System/InputProfile.h"
#include "System/LaunchAtLogin.h"
#include "Translator/TranslationHud.h"
#include "UI/CleanerOverlay.h"
#endif

namespace skey::windows {

TrayRuntime::TrayRuntime(StatusCallback callback, UpdateCallback update)
    : callback_(std::move(callback)), update_callback_(std::move(update)) {}
TrayRuntime::~TrayRuntime() { stop(); }

bool TrayRuntime::start() {
    bool expected = false;
    if (!running_.compare_exchange_strong(expected, true)) return false;
#ifdef _WIN32
    // Hook failure is non-fatal: tray + IPC still run in degraded mode.
    start_hook();
    start_update_checker();
#endif
    service_thread_ = std::thread(&TrayRuntime::service_loop, this);
    return true;
}

void TrayRuntime::stop() {
    if (!running_.exchange(false)) return;
#ifdef _WIN32
    if (update_bridge_) update_bridge_->alive.store(false);
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
        const auto alive = [this] { return running_.load(); };
        while (running_.load()) {
            if (!server.serve_once(endpoint, alive) && running_.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
            }
        }
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
    LocalizationService::shared().set_locale(settings.locale);
    {
        std::lock_guard<std::mutex> lock(settings_mutex_);
        current_settings_ = settings;
    }
    if (update_bridge_) {
        std::lock_guard<std::mutex> lock(update_bridge_->mutex);
        update_bridge_->settings = settings;
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

    // The profile switch makes browsers load/activate skey-tsf.dll. Best
    // effort: without the DLL (portable runs) push() fails and the pipeline
    // keeps using SendInput.
    sync_tsf_profile(settings.use_ime_for_browsers);

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
                if (pipeline_->cleaner_active()) {
                    pipeline_->set_cleaner_active(false);
                } else {
                    pipeline_->set_cleaner_active(true);
                    open_cleaner_overlay();
                }
                break;
            case HotkeyAction::translate: open_translation_hud(); break;
            // AI lands in a later phase; swallow the chord for now so it
            // doesn't leak into the app.
            case HotkeyAction::ai: break;
            case HotkeyAction::none: break;
            }
        });
    pipeline_->set_excluded_app_provider([this] { return foreground_is_excluded(); });

    // Phase 5: engine results in browsers go through skey-tsf.dll (TSF edit
    // inside the app) instead of SendInput, which Chromium omniboxes race.
    // The pusher returns false for non-browsers/unreachable DLL and the
    // pipeline falls back to KeyInjector.
    tsf_client_.open();
    pipeline_->set_tsf_pusher([this](int backspaces, const std::string& text) {
        SettingsModel snapshot;
        {
            std::lock_guard<std::mutex> lock(settings_mutex_);
            snapshot = current_settings_;
        }
        if (!snapshot.use_ime_for_browsers) return false;
        unsigned long pid = 0;
        const std::string exe = app_tracker_.current_exe(&pid);
        if (pid == 0 || !ForegroundAppTracker::is_browser(exe)) return false;
        return tsf_client_.push(static_cast<std::uint32_t>(pid), backspaces, text);
    });

    // Cleaner HUD: pipeline posts Esc-hold progress to the overlay window.
    if (!cleaner_bridge_) cleaner_bridge_ = std::make_shared<CleanerOverlayBridge>();
    {
        std::lock_guard<std::mutex> lock(cleaner_bridge_->mutex);
        cleaner_bridge_->unlock_request = [this] {
            if (pipeline_) pipeline_->set_cleaner_active(false);
        };
    }
    pipeline_->set_cleaner_listener(
        [bridge = cleaner_bridge_](TypingPipeline::CleanerEvent event, std::uint64_t clock_ms) {
            void* window = nullptr;
            {
                std::lock_guard<std::mutex> lock(bridge->mutex);
                window = bridge->window;
            }
            if (window == nullptr) return;
            std::uintptr_t code = 0;
            switch (event) {
            case TypingPipeline::CleanerEvent::esc_down: code = kCleanerEscDown; break;
            case TypingPipeline::CleanerEvent::esc_up: code = kCleanerEscUp; break;
            case TypingPipeline::CleanerEvent::other_key: code = kCleanerOtherKey; break;
            case TypingPipeline::CleanerEvent::deactivated: code = kCleanerDeactivated; break;
            case TypingPipeline::CleanerEvent::activated: return;
            }
            PostMessageW(static_cast<HWND>(window), kCleanerEventMessage, code,
                         static_cast<LPARAM>(clock_ms));
        });

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
    if (pipeline_ && pipeline_->cleaner_active()) {
        pipeline_->set_cleaner_active(false);  // closes the overlay, if open
    }
    hook_.uninstall();
    if (tsf_profile_active_) {
        InputProfile::restore();
        tsf_profile_active_ = false;
    }
    tsf_client_.close();
    if (cleaner_bridge_) {
        std::lock_guard<std::mutex> lock(cleaner_bridge_->mutex);
        cleaner_bridge_->unlock_request = nullptr;
    }
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

void TrayRuntime::sync_tsf_profile(bool wanted) {
    if (wanted && !tsf_profile_active_) {
        tsf_profile_active_ = InputProfile::activate();
    } else if (!wanted && tsf_profile_active_) {
        InputProfile::restore();
        tsf_profile_active_ = false;
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

void TrayRuntime::open_cleaner_overlay() {
    if (!cleaner_overlay_open_) {
        cleaner_overlay_open_ = std::make_shared<std::atomic<bool>>(false);
    }
    bool expected = false;
    if (!cleaner_overlay_open_->compare_exchange_strong(expected, true)) return;

    auto flag = cleaner_overlay_open_;
    auto bridge = cleaner_bridge_;
    std::thread([bridge, flag] {
        CleanerOverlay::run(bridge);
        flag->store(false);
    }).detach();
}

void TrayRuntime::start_update_checker() {
    if (!update_bridge_) update_bridge_ = std::make_shared<UpdateBridge>();
    {
        std::lock_guard<std::mutex> lock(update_bridge_->mutex);
        update_bridge_->alive.store(true);
    }
    std::shared_ptr<UpdateBridge> bridge = update_bridge_;
    UpdateCallback notify = update_callback_;
    const auto state_path = SettingsPaths::update_state_file();

    // Mirrors macOS UpdateChecker cadence: first check ~6s after launch,
    // then at most once per 24h, gated by the checkUpdates setting and
    // nagging only once per version.
    std::thread([bridge, notify = std::move(notify), state_path] {
        constexpr std::uint64_t kCooldownMs = 24ULL * 60 * 60 * 1000;
        const auto wait = [&bridge](std::uint64_t ms) {
            std::uint64_t waited = 0;
            while (waited < ms && bridge->alive.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(250));
                waited += 250;
            }
        };
        const auto now_ms = [] {
            return static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::system_clock::now().time_since_epoch())
                    .count());
        };

        bool first = true;
        while (bridge->alive.load()) {
            wait(first ? 6000 : 60 * 60 * 1000);  // 6s first, hourly after
            first = false;
            if (!bridge->alive.load()) break;

            bool check_enabled = false;
            {
                std::lock_guard<std::mutex> lock(bridge->mutex);
                check_enabled = bridge->settings.check_updates;
            }
            if (!check_enabled) continue;

            UpdateState state = UpdateChecker::load_state(state_path);
            const std::uint64_t now = now_ms();
            if (state.last_check_ms != 0 && now - state.last_check_ms < kCooldownMs) {
                continue;
            }

            const UpdateInfo info =
                UpdateChecker{make_platform_http()}.check(kAppVersion);
            state.last_check_ms = now_ms();
            if (info.available && info.version != state.dismissed_version) {
                state.dismissed_version = info.version;
                UpdateChecker::save_state(state_path, state);
                if (notify) notify(info);
            } else {
                UpdateChecker::save_state(state_path, state);
            }
        }
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
