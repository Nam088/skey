#include "../skey-tray/Hook/KeyClassifier.h"
#include "../skey-tray/Hook/ModifierTracker.h"

#include <array>
#include <cassert>
#include <initializer_list>

using namespace skey::windows;

int main() {
    // --- KeyClassifier LUT ---
    assert(KeyClassifier::classify(0x08) == KeyCategory::backspace);  // VK_BACK

    for (unsigned vk : {0x25u, 0x26u, 0x27u, 0x28u, 0x24u, 0x23u,
                        0x21u, 0x22u, 0x2Eu, 0x1Bu}) {
        assert(KeyClassifier::classify(vk) == KeyCategory::navigation);
    }
    for (unsigned vk : {0x0Du, 0x09u, 0x20u}) {
        assert(KeyClassifier::classify(vk) == KeyCategory::word_break);
    }
    for (unsigned vk : {0x10u, 0x11u, 0x12u, 0x14u, 0x5Bu, 0x5Cu,
                        0xA0u, 0xA1u, 0xA2u, 0xA3u, 0xA4u, 0xA5u}) {
        assert(KeyClassifier::classify(vk) == KeyCategory::modifier);
    }
    for (unsigned vk = 0x70; vk <= 0x87; ++vk) {
        assert(KeyClassifier::classify(vk) == KeyCategory::function_or_media);
    }
    assert(KeyClassifier::classify(0xAD) == KeyCategory::function_or_media);  // VK_VOLUME_MUTE
    assert(KeyClassifier::classify(0xA6) == KeyCategory::function_or_media);  // VK_BROWSER_BACK
    assert(KeyClassifier::classify('A') == KeyCategory::character);
    assert(KeyClassifier::classify('5') == KeyCategory::character);
    assert(KeyClassifier::classify(0xBA) == KeyCategory::character);  // OEM ;:
    assert(KeyClassifier::classify(300) == KeyCategory::character);   // out of LUT

    // --- ModifierTracker: bit packing shift=1, ctrl=2, alt=4, caps=8 ---
    ModifierTracker tracker;
    assert(tracker.mask() == 0);

    tracker.on_event(0xA0, false, false);  // LShift down
    assert(tracker.shift() && tracker.mask() == kModShift);
    tracker.on_event(0xA2, false, false);  // LCtrl down
    assert(tracker.mask() == (kModShift | kModCtrl));
    tracker.on_event(0xA4, false, false);  // LAlt down
    assert(tracker.mask() == (kModShift | kModCtrl | kModAlt));

    // CapsLock toggles on the physical down edge only.
    tracker.on_event(0x14, false, false);
    assert(tracker.caps_lock() && tracker.mask() == 15);
    tracker.on_event(0x14, true, false);
    assert(tracker.caps_lock());
    tracker.on_event(0x14, false, false);
    tracker.on_event(0x14, true, false);
    assert(!tracker.caps_lock());

    // Auto-repeated downs must not re-toggle.
    tracker.on_event(0x14, false, false);
    tracker.on_event(0x14, false, false);
    assert(tracker.caps_lock());
    tracker.on_event(0x14, true, false);
    assert(tracker.caps_lock());

    // Generic VK_SHIFT with the extended flag is the right Shift key.
    ModifierTracker right_side;
    right_side.on_event(0x10, false, true);
    assert(right_side.shift());
    right_side.on_event(0x10, true, true);
    assert(!right_side.shift());
    right_side.on_event(0x11, false, true);  // VK_CONTROL extended = RCtrl
    assert(right_side.ctrl());
    right_side.on_event(0x11, true, true);
    right_side.on_event(0x12, false, true);  // VK_MENU extended = RAlt
    assert(right_side.alt());
    right_side.on_event(0x12, true, true);
    assert(right_side.mask() == 0);

    // Win keys tracked separately from Ctrl/Alt.
    ModifierTracker win_tracker;
    win_tracker.on_event(0x5B, false, false);
    assert(win_tracker.win() && win_tracker.mask() == 0);
    win_tracker.on_event(0x5B, true, false);
    assert(!win_tracker.win());

    // Key-state array for ToUnicode.
    ModifierTracker state_tracker;
    state_tracker.on_event(0xA0, false, false);
    state_tracker.on_event(0x14, false, false);
    std::array<uint8_t, 256> state{};
    state_tracker.build_key_state(state);
    assert(state[0xA0] == 0x80);
    assert(state[0x14] == 0x01);
    assert(state[0xA2] == 0);

    return 0;
}
