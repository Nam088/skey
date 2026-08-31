#pragma once

#include "../Shared/IPC/IpcTransport.h"

#include <atomic>
#include <cstdint>
#include <functional>
#include <thread>

#ifdef _WIN32
#include <memory>

#include "Engine/MacroEngine.h"
#include "Engine/SKeyEngineWrapper.h"
#include "Hook/KeyboardHook.h"
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

private:
    void service_loop();
#ifdef _WIN32
    bool start_hook();
    void stop_hook();
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
#endif
};

} // namespace skey::windows
