#pragma once

#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <string>
#include <thread>

namespace skey::windows {

// Polls the system clipboard every 500ms (mirroring the macOS
// ClipboardMonitor changeCount polling) and reports new UTF-8 text.
// Own writes are suppressed via pause(), matching the macOS store pause.
class ClipboardMonitor {
public:
    using Capture = std::function<void(std::string utf8)>;

    explicit ClipboardMonitor(Capture capture);
    ~ClipboardMonitor();

    ClipboardMonitor(const ClipboardMonitor&) = delete;
    ClipboardMonitor& operator=(const ClipboardMonitor&) = delete;

    void start();
    void stop();

    // Ignore clipboard changes for the given duration (used around our own
    // paste-prepare writes so we don't re-capture them).
    void pause_for(std::chrono::milliseconds duration);

private:
    void loop();

    Capture capture_;
    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<std::int64_t> paused_until_ms_{0};
};

} // namespace skey::windows
