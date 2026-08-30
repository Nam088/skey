#pragma once

#include "../Shared/IPC/IpcTransport.h"

#include <atomic>
#include <cstdint>
#include <functional>
#include <thread>

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
    std::atomic<bool> running_{false};
    std::atomic<bool> vietnamese_enabled_{true};
    StatusCallback callback_;
    std::thread service_thread_;
    std::thread ipc_thread_;
};

} // namespace skey::windows
