#pragma once

#include "../Shared/Contracts/SettingsModel.h"
#include "../Shared/IPC/IpcTransport.h"

#include <atomic>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <mutex>
#include <thread>

#ifdef _WIN32
#include <memory>

#include "Engine/MacroEngine.h"
#include "Engine/SKeyEngineWrapper.h"
#include "Hook/KeyboardHook.h"
#include "Pipeline/ForegroundAppTracker.h"
#include "Pipeline/TypingPipeline.h"
#endif

namespace skey::windows {

class TrayRuntime final {
public:
    using StatusCallback = std::function<void(bool vietnamese_enabled)>;
    explicit TrayRuntime(StatusCallback callback = {});
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
#endif

    std::atomic<bool> running_{false};
    std::atomic<bool> vietnamese_enabled_{true};
    StatusCallback callback_;
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

    std::mutex settings_mutex_;
    SettingsModel current_settings_;
    std::filesystem::file_time_type settings_mtime_{};
    std::filesystem::file_time_type macros_mtime_{};
    bool smart_switch_active_{false};
    std::string last_foreground_exe_;
#endif
};

} // namespace skey::windows
