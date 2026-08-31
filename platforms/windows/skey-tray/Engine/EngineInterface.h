#pragma once

#include <string>

namespace skey::windows {

// Typing-engine abstraction so the pipeline can run against the real
// skey-capi wrapper (SKeyEngineWrapper) or a fake in unit tests.
class EngineInterface {
public:
    struct Result {
        bool handled = false;
        int backspaces = 0;
        std::string text;  // UTF-8
    };

    virtual ~EngineInterface() = default;
    virtual void reset() = 0;
    virtual void set_caps_state(bool shift_pressed, bool caps_lock_on) = 0;
    virtual Result filter(char32_t character) = 0;
    virtual Result backspace() = 0;
    virtual Result restore() = 0;
};

} // namespace skey::windows
