#pragma once

#include <atomic>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace skey::windows {

// O(1) in-memory macro expander for typing shortcuts.
// Port of platforms/macos/.../MacroEngine.swift. Keys and word buffer are
// ASCII (the pipeline only records printable ASCII 33..126).
class MacroEngine {
public:
    struct MatchResult {
        bool handled = false;
        int backspaces = 0;
        std::string replacement;  // UTF-8

        static MatchResult unhandled() { return {}; }
    };

    using MacroEntry = std::pair<std::string, std::string>;

    void reload(const std::vector<MacroEntry>& macros);
    void set_enabled(bool enabled) noexcept;
    void set_auto_caps(bool enabled) noexcept;

    void reset();
    void record_char(char32_t ch);
    void record_backspace();
    MatchResult evaluate_on_space();

private:
    std::mutex mutex_;
    std::unordered_map<std::string, std::string> macros_;
    std::string word_;
    std::atomic<bool> enabled_{false};
    std::atomic<bool> auto_caps_{false};
};

} // namespace skey::windows
