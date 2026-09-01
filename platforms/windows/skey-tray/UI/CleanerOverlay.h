#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>

namespace skey::windows {

// Custom window message carrying cleaner progress events to the overlay.
// wParam = kCleaner* code, lParam = pipeline-clock milliseconds.
inline constexpr unsigned kCleanerEventMessage = 0xB002;
inline constexpr std::uintptr_t kCleanerEscDown = 0;
inline constexpr std::uintptr_t kCleanerEscUp = 1;
inline constexpr std::uintptr_t kCleanerOtherKey = 2;
inline constexpr std::uintptr_t kCleanerDeactivated = 3;

// Shared between the hook thread (event poster), TrayRuntime and the overlay
// thread, so none of them touches freed state.
struct CleanerOverlayBridge {
    std::mutex mutex;
    void* window = nullptr;             // HWND of the live overlay, if any
    std::function<void()> unlock_request;  // overlay click -> deactivate cleaner
};

// Keyboard Cleaner HUD (macOS KeyboardCleanerView parity): topmost capsule
// showing the locked state and an Esc-hold progress ring. run() drives a
// modal loop on the calling thread and returns once the cleaner unlocks.
class CleanerOverlay {
public:
    static void run(std::shared_ptr<CleanerOverlayBridge> bridge);
};

} // namespace skey::windows
