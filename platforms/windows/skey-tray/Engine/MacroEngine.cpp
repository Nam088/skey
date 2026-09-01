#include "MacroEngine.h"

#include <algorithm>
#include <cctype>

namespace skey::windows {

namespace {

constexpr std::size_t kMaxWordLength = 64;

char ascii_lower(char c) {
    return static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
}

char ascii_upper(char c) {
    return static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
}

std::string lowercased(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), ascii_lower);
    return s;
}

std::string trimmed(const std::string& s) {
    const char* ws = " \t\n\r";
    const auto first = s.find_first_not_of(ws);
    if (first == std::string::npos) return {};
    const auto last = s.find_last_not_of(ws);
    return s.substr(first, last - first + 1);
}

bool is_ascii_upper(char c) { return c >= 'A' && c <= 'Z'; }

} // namespace

void MacroEngine::reload(const std::vector<MacroEntry>& macros) {
    std::lock_guard<std::mutex> lock(mutex_);
    macros_.clear();
    for (const auto& [shortcut, replacement] : macros) {
        const std::string key = lowercased(trimmed(shortcut));
        if (!key.empty()) {
            macros_[key] = replacement;
        }
    }
}

void MacroEngine::set_enabled(bool enabled) noexcept {
    enabled_.store(enabled);
}

void MacroEngine::set_auto_caps(bool enabled) noexcept {
    auto_caps_.store(enabled);
}

void MacroEngine::reset() {
    std::lock_guard<std::mutex> lock(mutex_);
    word_.clear();
}

void MacroEngine::record_char(char32_t ch) {
    // The pipeline only forwards printable ASCII; anything else is treated
    // as a word break (mirrors Swift's isWhitespace/isNewline handling).
    if (ch < 33 || ch > 126) {
        reset();
        return;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    word_.push_back(static_cast<char>(ch));
    if (word_.size() > kMaxWordLength) {
        word_.erase(word_.begin());
    }
}

void MacroEngine::record_backspace() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!word_.empty()) word_.pop_back();
}

MacroEngine::MatchResult MacroEngine::evaluate_on_space() {
    if (!enabled_.load()) {
        reset();
        return MatchResult::unhandled();
    }

    std::lock_guard<std::mutex> lock(mutex_);
    if (word_.empty()) return MatchResult::unhandled();

    const std::string typed = word_;
    word_.clear();

    const auto it = macros_.find(lowercased(typed));
    if (it == macros_.end()) return MatchResult::unhandled();

    std::string replacement = it->second;

    // Auto-Caps: ALL-CAPS typed word -> uppercased replacement;
    // Capitalized typed word -> capitalized replacement.
    if (auto_caps_.load()) {
        const bool all_upper = typed.size() > 1 &&
            std::all_of(typed.begin(), typed.end(), is_ascii_upper);
        if (all_upper) {
            std::transform(replacement.begin(), replacement.end(),
                           replacement.begin(), ascii_upper);
        } else if (is_ascii_upper(typed.front())) {
            if (!replacement.empty()) replacement[0] = ascii_upper(replacement[0]);
        }
    }

    replacement.push_back(' ');
    return MatchResult{true, static_cast<int>(typed.size()), replacement};
}

} // namespace skey::windows
