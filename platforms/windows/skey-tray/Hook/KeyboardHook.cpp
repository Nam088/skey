#ifdef _WIN32

#include "KeyboardHook.h"

#include <chrono>
#include <condition_variable>
#include <mutex>

namespace skey::windows {

namespace {
constexpr UINT kMsgReinstall = WM_APP + 100;
constexpr DWORD kWatchdogIntervalMs = 2000;
constexpr DWORD kProbeWaitMs = 300;
} // namespace

std::atomic<KeyboardHook*> KeyboardHook::instance_{nullptr};

KeyboardHook::KeyboardHook() = default;

KeyboardHook::~KeyboardHook() {
    uninstall();
}

bool KeyboardHook::install(KeyCallback key_cb, MouseClickCallback mouse_cb) {
    if (running_.load()) return false;

    KeyboardHook* expected = nullptr;
    if (!instance_.compare_exchange_strong(expected, this)) return false;

    key_cb_ = std::move(key_cb);
    mouse_cb_ = std::move(mouse_cb);
    running_.store(true);
    thread_exited_.store(false);

    std::atomic<bool> ready{false};
    hook_thread_ = std::thread([this, &ready] {
        hook_thread_id_ = GetCurrentThreadId();
        key_hook_.store(SetWindowsHookExW(WH_KEYBOARD_LL, key_proc, GetModuleHandleW(nullptr), 0));
        mouse_hook_.store(SetWindowsHookExW(WH_MOUSE_LL, mouse_proc, GetModuleHandleW(nullptr), 0));
        ready.store(true);

        MSG msg{};
        while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
            if (msg.message == kMsgReinstall) {
                reinstall();
                continue;
            }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }

        if (HHOOK h = key_hook_.exchange(nullptr)) UnhookWindowsHookEx(h);
        if (HHOOK h = mouse_hook_.exchange(nullptr)) UnhookWindowsHookEx(h);
        thread_exited_.store(true);
    });

    // Wait for the hook thread to finish installing (bounded: thread creation
    // + SetWindowsHookEx is a few ms).
    for (int i = 0; i < 1000 && !ready.load(); ++i) Sleep(1);

    if (!key_hook_.load()) {
        uninstall();
        return false;
    }

    watchdog_thread_ = std::thread([this] { watchdog_loop(); });
    return true;
}

void KeyboardHook::uninstall() {
    if (!running_.exchange(false)) {
        if (hook_thread_.joinable()) hook_thread_.join();
        return;
    }

    if (hook_thread_id_ != 0) {
        for (int i = 0; i < 200 && !thread_exited_.load(); ++i) {
            PostThreadMessageW(hook_thread_id_, WM_QUIT, 0, 0);
            Sleep(10);
        }
    }
    {
        std::lock_guard<std::mutex> lk(cv_mutex_);
        cv_.notify_all();
    }
    if (hook_thread_.joinable()) hook_thread_.join();
    if (watchdog_thread_.joinable()) watchdog_thread_.join();

    KeyboardHook* self = this;
    instance_.compare_exchange_strong(self, nullptr);
}

void KeyboardHook::reinstall() {
    if (HHOOK old = key_hook_.exchange(nullptr)) UnhookWindowsHookEx(old);
    if (HHOOK old = mouse_hook_.exchange(nullptr)) UnhookWindowsHookEx(old);
    key_hook_.store(SetWindowsHookExW(WH_KEYBOARD_LL, key_proc, GetModuleHandleW(nullptr), 0));
    mouse_hook_.store(SetWindowsHookExW(WH_MOUSE_LL, mouse_proc, GetModuleHandleW(nullptr), 0));
}

void KeyboardHook::watchdog_loop() {
    while (running_.load()) {
        std::unique_lock<std::mutex> lk(cv_mutex_);
        if (cv_.wait_for(lk, std::chrono::milliseconds(kWatchdogIntervalMs),
                         [this] { return !running_.load(); })) {
            break;
        }
        lk.unlock();

        if (!probe_hook() && running_.load()) {
            // Probe never reached the callback: Windows silently removed
            // the hook. Re-install on the hook thread (WH_KEYBOARD_LL is
            // bound to the thread that installs it).
            PostThreadMessageW(hook_thread_id_, kMsgReinstall, 0, 0);
        }
    }
}

bool KeyboardHook::probe_hook() {
    probe_seen_.store(false);
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = VK_F24;
    input.ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, &input, sizeof(input));
    Sleep(kProbeWaitMs);
    return probe_seen_.load();
}

LRESULT CALLBACK KeyboardHook::key_proc(int code, WPARAM wp, LPARAM lp) {
    KeyboardHook* self = instance_.load(std::memory_order_acquire);
    if (code == HC_ACTION && self != nullptr) {
        const auto* kb = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lp);
        const bool is_up = (wp == WM_KEYUP || wp == WM_SYSKEYUP);
        const bool injected = (kb->flags & LLKHF_INJECTED) != 0;

        // Watchdog probe: an injected F24 key-up must always pass through.
        if (is_up && injected && kb->vkCode == VK_F24) {
            self->probe_seen_.store(true);
            return CallNextHookEx(nullptr, code, wp, lp);
        }

        if (self->key_cb_) {
            HookKeyEvent ev{kb->vkCode, kb->scanCode, kb->flags, is_up,
                            injected, (kb->flags & LLKHF_EXTENDED) != 0};
            if (self->key_cb_(ev)) return 1;  // swallow
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

LRESULT CALLBACK KeyboardHook::mouse_proc(int code, WPARAM wp, LPARAM lp) {
    KeyboardHook* self = instance_.load(std::memory_order_acquire);
    if (code == HC_ACTION && self != nullptr && self->mouse_cb_) {
        if (wp == WM_LBUTTONDOWN || wp == WM_RBUTTONDOWN || wp == WM_MBUTTONDOWN) {
            self->mouse_cb_();
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

} // namespace skey::windows

#endif // _WIN32
