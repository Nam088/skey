#include "TrayRuntime.h"

#include <utility>
#ifdef _WIN32
#include <windows.h>
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
    const bool enabled = !vietnamese_enabled_.load();
    vietnamese_enabled_.store(enabled);
#ifdef _WIN32
    if (pipeline_) {
        auto config = pipeline_->config();
        config.vietnamese = enabled;
        pipeline_->set_config(config);
    }
    if (engine_) engine_->reset();
    macro_.reset();
#endif
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

#ifdef _WIN32

bool TrayRuntime::start_hook() {
    engine_ = std::make_unique<SKeyEngineWrapper>();
    pipeline_ = std::make_unique<TypingPipeline>(
        *engine_, macro_, [this](HotkeyAction action) {
            if (action == HotkeyAction::toggle_language) toggle_language();
        });

    TypingPipeline::Config config;
    config.vietnamese = vietnamese_enabled_.load();
    pipeline_->set_config(config);

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

#endif

} // namespace skey::windows
