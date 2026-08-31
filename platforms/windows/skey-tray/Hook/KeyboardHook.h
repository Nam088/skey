#pragma once

#ifdef _WIN32

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <thread>

#include "HookKeyEvent.h"

namespace skey::windows {

// WH_KEYBOARD_LL wrapper running on its own message-loop thread.
//
// The callback returns true to swallow the event (block it from reaching
// the focused application) or false to pass it through. The callback MUST
// complete well under 1 second — Windows 10 1709+ silently removes hooks
// that block. A watchdog probes the hook with an injected F24 key-up
// every 2 seconds and re-installs it on the hook thread if the probe is
// not observed (i.e. Windows removed the hook).
class KeyboardHook {
public:
    using KeyCallback = std::function<bool(const HookKeyEvent&)>;
    using MouseClickCallback = std::function<void()>;

    KeyboardHook();
    ~KeyboardHook();
    KeyboardHook(const KeyboardHook&) = delete;
    KeyboardHook& operator=(const KeyboardHook&) = delete;

    bool install(KeyCallback key_cb, MouseClickCallback mouse_cb = {});
    void uninstall();
    bool installed() const noexcept { return key_hook_.load(std::memory_order_acquire) != nullptr; }

private:
    static LRESULT CALLBACK key_proc(int code, WPARAM wp, LPARAM lp);
    static LRESULT CALLBACK mouse_proc(int code, WPARAM wp, LPARAM lp);
    void hook_thread_main();
    void reinstall();
    void watchdog_loop();
    bool probe_hook();

    KeyCallback key_cb_;
    MouseClickCallback mouse_cb_;
    std::thread hook_thread_;
    std::thread watchdog_thread_;
    DWORD hook_thread_id_ = 0;
    std::atomic<HHOOK> key_hook_{nullptr};
    std::atomic<HHOOK> mouse_hook_{nullptr};
    std::atomic<bool> running_{false};
    std::atomic<bool> probe_seen_{false};
    std::atomic<bool> thread_exited_{false};
    std::mutex cv_mutex_;
    std::condition_variable cv_;
    static std::atomic<KeyboardHook*> instance_;
};

} // namespace skey::windows

#endif // _WIN32
