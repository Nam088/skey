#pragma once

#include "../../../Shared/Contracts/SettingsModel.h"

#include <bit>
#include <optional>

namespace skey::windows {

// Recorder state machine ported from macOS ShortcutRecorderView:
// - Escape without modifiers cancels.
// - A non-modifier key commits when held with modifiers, or alone if it is a
//   function key.
// - Modifier-only chords commit when all modifiers are released after at
//   least two were held during the session.
class ShortcutRecorderModel final {
public:
    void begin() {
        recording_ = true;
        live_modifiers_ = 0;
        peak_modifiers_ = 0;
        captured_.reset();
    }

    void cancel() {
        recording_ = false;
        live_modifiers_ = 0;
        peak_modifiers_ = 0;
    }

    // Returns true when the recording session ended (cancel or capture).
    bool on_key_down(unsigned vk, unsigned modifiers) {
        if (!recording_) return false;
        if (vk == kVkEscape && modifiers == 0) {
            cancel();
            return true;
        }
        peak_modifiers_ = 0;
        if (modifiers != 0 || is_function_key(vk)) {
            captured_ = HotkeyRecord{{}, vk, modifiers};
            recording_ = false;
            return true;
        }
        return false;
    }

    // Returns true when the recording session ended (modifier-only capture).
    bool on_modifiers_changed(unsigned modifiers) {
        if (!recording_) return false;
        live_modifiers_ = modifiers;
        if (modifiers != 0) {
            peak_modifiers_ |= modifiers;
            return false;
        }
        if (peak_modifiers_ == 0) return false;
        if (std::popcount(peak_modifiers_) >= 2) {
            captured_ = HotkeyRecord{{}, 0, peak_modifiers_};
            recording_ = false;
            return true;
        }
        peak_modifiers_ = 0;
        return false;
    }

    bool recording() const { return recording_; }
    unsigned live_modifiers() const { return live_modifiers_; }
    unsigned peak_modifiers() const { return peak_modifiers_; }
    const std::optional<HotkeyRecord>& captured() const { return captured_; }

    static bool is_function_key(unsigned vk) { return vk >= 0x70 && vk <= 0x87; }

    static constexpr unsigned kVkEscape = 0x1B;

private:
    bool recording_{false};
    unsigned live_modifiers_{0};
    unsigned peak_modifiers_{0};
    std::optional<HotkeyRecord> captured_{};
};

} // namespace skey::windows
