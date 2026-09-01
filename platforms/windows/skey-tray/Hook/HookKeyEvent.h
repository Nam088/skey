#pragma once

namespace skey::windows {

// One keyboard event as delivered by the WH_KEYBOARD_LL hook.
struct HookKeyEvent {
    unsigned vk;
    unsigned scan;
    unsigned flags;  // raw KBDLLHOOKSTRUCT flags
    bool is_up;
    bool is_injected;
    bool is_extended;
};

} // namespace skey::windows
