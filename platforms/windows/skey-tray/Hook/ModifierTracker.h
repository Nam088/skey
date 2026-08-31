#pragma once

#include <array>
#include <cstdint>

namespace skey::windows {

// Modifier bit packing (shared with tests): shift=1, ctrl=2, alt=4, caps=8.
enum ModifierBits : uint8_t {
    kModShift = 1 << 0,
    kModCtrl = 1 << 1,
    kModAlt = 1 << 2,
    kModCaps = 1 << 3,
};

// Tracks modifier state exclusively from hook events. GetAsyncKeyState /
// GetKeyState cannot be trusted inside a WH_KEYBOARD_LL callback because
// the reported state may lag the intercepted event.
//
// Not thread-safe by design: all updates and reads happen on the hook
// thread (same thread that runs the LL hook callback).
class ModifierTracker {
public:
    // Feed one keyboard event. `extended` is the LLKHF_EXTENDED flag and is
    // used to distinguish right-side Shift/Ctrl/Alt (which arrive as the
    // generic VK_SHIFT / VK_CONTROL / VK_MENU codes).
    void on_event(unsigned vk, bool is_key_up, bool extended) noexcept {
        switch (vk) {
        case kVkShift: extended ? r_shift_ = !is_key_up : l_shift_ = !is_key_up; break;
        case kVkLShift: l_shift_ = !is_key_up; break;
        case kVkRShift: r_shift_ = !is_key_up; break;
        case kVkControl: extended ? r_ctrl_ = !is_key_up : l_ctrl_ = !is_key_up; break;
        case kVkLControl: l_ctrl_ = !is_key_up; break;
        case kVkRControl: r_ctrl_ = !is_key_up; break;
        case kVkMenu: extended ? r_alt_ = !is_key_up : l_alt_ = !is_key_up; break;
        case kVkLMenu: l_alt_ = !is_key_up; break;
        case kVkRMenu: r_alt_ = !is_key_up; break;
        case kVkLWin: l_win_ = !is_key_up; break;
        case kVkRWin: r_win_ = !is_key_up; break;
        case kVkCapital:
            // Toggle only on the physical down edge; auto-repeated downs
            // must not re-toggle.
            if (!is_key_up && !capital_held_) caps_lock_ = !caps_lock_;
            capital_held_ = !is_key_up;
            break;
        default: break;
        }
    }

    bool shift() const noexcept { return l_shift_ || r_shift_; }
    bool ctrl() const noexcept { return l_ctrl_ || r_ctrl_; }
    bool alt() const noexcept { return l_alt_ || r_alt_; }
    bool win() const noexcept { return l_win_ || r_win_; }
    bool caps_lock() const noexcept { return caps_lock_; }

    uint8_t mask() const noexcept {
        uint8_t m = 0;
        if (shift()) m |= kModShift;
        if (ctrl()) m |= kModCtrl;
        if (alt()) m |= kModAlt;
        if (caps_lock_) m |= kModCaps;
        return m;
    }

    // Builds the 256-byte key state array expected by ToUnicode().
    void build_key_state(std::array<uint8_t, 256>& state) const noexcept {
        state.fill(0);
        if (l_shift_) state[kVkLShift] = 0x80;
        if (r_shift_) state[kVkRShift] = 0x80;
        if (l_ctrl_) state[kVkLControl] = 0x80;
        if (r_ctrl_) state[kVkRControl] = 0x80;
        if (l_alt_) state[kVkLMenu] = 0x80;
        if (r_alt_) state[kVkRMenu] = 0x80;
        if (caps_lock_) state[kVkCapital] = 0x01;
    }

    void reset() noexcept { *this = ModifierTracker(); }

    static constexpr unsigned kVkBack = 0x08;
    static constexpr unsigned kVkShift = 0x10;
    static constexpr unsigned kVkControl = 0x11;
    static constexpr unsigned kVkMenu = 0x12;
    static constexpr unsigned kVkCapital = 0x14;
    static constexpr unsigned kVkLWin = 0x5B;
    static constexpr unsigned kVkRWin = 0x5C;
    static constexpr unsigned kVkLShift = 0xA0;
    static constexpr unsigned kVkRShift = 0xA1;
    static constexpr unsigned kVkLControl = 0xA2;
    static constexpr unsigned kVkRControl = 0xA3;
    static constexpr unsigned kVkLMenu = 0xA4;
    static constexpr unsigned kVkRMenu = 0xA5;

private:
    bool l_shift_ = false;
    bool r_shift_ = false;
    bool l_ctrl_ = false;
    bool r_ctrl_ = false;
    bool l_alt_ = false;
    bool r_alt_ = false;
    bool l_win_ = false;
    bool r_win_ = false;
    bool caps_lock_ = false;
    bool capital_held_ = false;
};

} // namespace skey::windows
