#pragma once

#include "../Shared/Contracts/SettingsModel.h"
#include "../Shared/IPC/IpcTransport.h"
#include "../Shared/Updates/UpdateChecker.h"

#include <atomic>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <mutex>
#include <thread>

#ifdef _WIN32
#include <memory>

#include "../Shared/Clipboard/ClipboardHistoryStore.h"
#include "Clipboard/ClipboardMonitor.h"
#include "Engine/MacroEngine.h"
#include "Engine/SKeyEngineWrapper.h"
#include "Hook/KeyboardHook.h"
#include "Pipeline/ForegroundAppTracker.h"
#include "Pipeline/TypingPipeline.h"
#include "Translator/TranslationHud.h"
#include "UI/CleanerOverlay.h"
#endif

namespace skey::windows {

class TrayRuntime final {
public:
    using StatusCallback = std::function<void(bool vietnamese_enabled)>;
    using UpdateCallback = std::function<void(UpdateInfo)>;
    explicit TrayRuntime(StatusCallback callback = {}, UpdateCallback update = {});
    ~TrayRuntime();
    TrayRuntime(const TrayRuntime&) = delete;
    TrayRuntime& operator=(const TrayRuntime&) = delete;

    bool start();
    bool start_ipc(IpcHandler handler, std::string endpoint = kIpcPipeName);
    void stop();
    bool running() const noexcept { return running_.load(); }
    bool vietnamese_enabled() const noexcept { return vietnamese_enabled_.load(); }
    bool toggle_language();

    // Pushes a settings snapshot into the engine/pipeline/hotkeys/macros.
    void apply_settings(const SettingsModel& settings);

private:
    void service_loop();
    void set_language(bool vietnamese);
#ifdef _WIN32
    bool start_hook();
    void stop_hook();
    void reload_settings_if_changed();
    void update_smart_app_switch();
    bool foreground_is_excluded();
    void open_clipboard_popup();
    void on_clipboard_capture(std::string text);
    void open_translation_hud();
    void open_cleaner_overlay();
    void start_update_checker();
#endif

    std::atomic<bool> running_{false};
    std::atomic<bool> vietnamese_enabled_{true};
    StatusCallback callback_;
    UpdateCallback update_callback_;
    std::thread service_thread_;
    std::thread ipc_thread_;
#ifdef _WIN32
    // Declaration order matters: hook_ must be destroyed (uninstalled)
    // before the pipeline and engine it calls into.
    std::unique_ptr<SKeyEngineWrapper> engine_;
    MacroEngine macro_;
    std::unique_ptr<TypingPipeline> pipeline_;
    KeyboardHook hook_;
    ForegroundAppTracker app_tracker_;
    std::unique_ptr<ClipboardHistoryStore> clipboard_store_;
    std::unique_ptr<ClipboardMonitor> clipboard_monitor_;
    // Shared with the detached popup/HUD threads so they never touch `this`.
    std::shared_ptr<std::atomic<bool>> clipboard_popup_open_;
    std::shared_ptr<std::atomic<bool>> translation_hud_open_;
    std::shared_ptr<std::atomic<bool>> cleaner_overlay_open_;
    std::shared_ptr<CleanerOverlayBridge> cleaner_bridge_;
    std::mutex clipboard_mutex_;

    // Kept alive by the detached update-checker thread.
    struct UpdateBridge {
        std::mutex mutex;
        SettingsModel settings;
        std::atomic<bool> alive{true};
    };
    std::shared_ptr<UpdateBridge> update_bridge_;

    std::mutex settings_mutex_;
    SettingsModel current_settings_;
    std::filesystem::file_time_type settings_mtime_{};
    std::filesystem::file_time_type macros_mtime_{};
    bool smart_switch_active_{false};
    std::string last_foreground_exe_;
#endif
};

} // namespace skey::windows
