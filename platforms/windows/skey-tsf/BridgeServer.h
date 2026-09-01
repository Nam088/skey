#pragma once

#include <atomic>
#include <thread>

#include "SKeyTsfGlobals.h"
#include "../Shared/TsfBridge/TsfBridge.h"

// The protocol constants and frame type live in the shared skey::windows
// namespace; this header is private to skey-tsf.dll.
using namespace skey::windows;

namespace skey::tsf {

// Message delivered to the text service window on the TSF thread.
constexpr UINT kSKeyTsfApplyMessage = WM_APP + 0x151;

struct BridgeApplyMsg {
    int backspaces = 0;
    std::uint32_t text_len = 0;
    wchar_t text[kTsfMaxTextUnits + 1]{};
};

// One worker per browser process (TSF activates the text service on every
// thread with a text context; the bridge itself is process-wide). The worker
// waits on the per-process request event the EXE signals, then synchronously
// forwards each frame to the text service window so edits stay in order.
class BridgeServer {
public:
    static void attach(HWND service_window);
    static void detach();

private:
    static void worker();

    static std::atomic<int> refs_;
    static std::atomic<HWND> window_;
    static std::atomic<bool> running_;
    static std::thread thread_;
};

} // namespace skey::tsf
