#include "TrayRuntime.h"

#include <utility>

namespace skey::windows {

TrayRuntime::TrayRuntime(StatusCallback callback) : callback_(std::move(callback)) {}
TrayRuntime::~TrayRuntime() { stop(); }

bool TrayRuntime::start() {
    bool expected = false;
    if (!running_.compare_exchange_strong(expected, true)) return false;
    service_thread_ = std::thread(&TrayRuntime::service_loop, this);
    return true;
}

void TrayRuntime::stop() {
    if (!running_.exchange(false)) return;
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
    const bool enabled = !vietnamese_enabled_.load();
    vietnamese_enabled_.store(enabled);
    if (callback_) callback_(enabled);
    return true;
}

void TrayRuntime::service_loop() {
#ifdef _WIN32
    // The native message loop is owned by TrayApp; this thread is reserved for
    // service/IPC lifetime and remains idle until the shell is wired in.
    while (running_.load()) ::Sleep(25);
#else
    // Portable test lifecycle: no platform loop is required.
#endif
}

} // namespace skey::windows
