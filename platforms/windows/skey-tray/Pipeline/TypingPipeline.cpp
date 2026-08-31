#include "TypingPipeline.h"

#include <array>
#include <chrono>

#include "KeyInjector.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

namespace {
constexpr unsigned kVkSpace = 0x20;
constexpr unsigned kVkEscape = 0x1B;
} // namespace

TypingPipeline::TypingPipeline(EngineInterface& engine, MacroEngine& macro,
                               ActionCallback on_action)
    : engine_(engine), macro_(macro), on_action_(std::move(on_action)) {}

void TypingPipeline::on_mouse_click() {
    engine_.reset();
    macro_.reset();
    modifier_only_candidate_ = false;
}

void TypingPipeline::set_config(const Config& config) {
    std::lock_guard<std::mutex> lock(config_mutex_);
    config_ = config;
}

TypingPipeline::Config TypingPipeline::config() const {
    std::lock_guard<std::mutex> lock(config_mutex_);
    return config_;
}

void TypingPipeline::set_excluded_app_provider(ExcludedAppProvider provider) {
    std::lock_guard<std::mutex> lock(config_mutex_);
    excluded_app_provider_ = std::move(provider);
}

bool TypingPipeline::process(const HookKeyEvent& event) {
    // Stage 1: pass through events injected by SKey itself.
    if (event.is_injected) return false;

    Config cfg;
    ExcludedAppProvider excluded;
    {
        std::lock_guard<std::mutex> lock(config_mutex_);
        cfg = config_;
        excluded = excluded_app_provider_;
    }

    // Stage 2: hook disabled -> pass.
    if (!cfg.hook_enabled) return false;

    const KeyCategory category = KeyClassifier::classify(event.vk);

    // Modifier state is tracked from events only (GetAsyncKeyState is not
    // trustworthy inside a LL hook callback).
    tracker_.on_event(event.vk, event.is_up, event.is_extended);

    // Stage 3b: Keyboard Cleaner blocks every key (modifiers included); only
    // its own hotkey or holding Esc for 2s releases it. Runs before the
    // modifier-only chord stage so chords cannot leak through while cleaning.
    if (cleaner_active_) return handle_cleaner(event);

    // Stage 4: modifier-only chord for language toggle (e.g. Ctrl+Shift).
    if (category == KeyCategory::modifier) {
        if (hotkeys_.language_is_modifier_only()) {
            const uint8_t target = hotkeys_.language_modifiers();
            const uint8_t mods = tracker_.mask() & ~kModCaps;
            if (mods == target) {
                modifier_only_candidate_ = true;
            } else if (mods == 0 && modifier_only_candidate_) {
                modifier_only_candidate_ = false;
                if (on_action_) on_action_(HotkeyAction::toggle_language);
            } else if ((mods & target) != mods) {
                modifier_only_candidate_ = false;
            }
        }
        return false;
    }

    // Any regular key cancels the modifier-only chord.
    modifier_only_candidate_ = false;

    // Stage 5: hotkeys swallow both key-down and key-up.
    const uint8_t mods = tracker_.mask() & ~kModCaps;
    const HotkeyAction action = hotkeys_.match(event.vk, mods);
    if (action != HotkeyAction::none) {
        if (!event.is_up && on_action_) on_action_(action);
        return true;
    }

    // Stage 5b: swallowed-key restore (Ctrl+Shift+Esc). Only swallow when the
    // restore produced output; otherwise pass the chord through so the system
    // Task Manager shortcut keeps working.
    if (cfg.restore_enabled && event.vk == kVkEscape && !event.is_up &&
        mods == (kModCtrl | kModShift)) {
        const auto restored = engine_.restore();
        if (restored.handled) {
            KeyInjector::inject(restored.backspaces, restored.text);
            return true;
        }
        return false;
    }

    // Stage 6: Win/Ctrl/Alt combos reset engines and pass through.
    if (tracker_.win() || tracker_.ctrl() || tracker_.alt()) {
        engine_.reset();
        macro_.reset();
        return false;
    }

    // Stage 7: key-up passes through, engine state preserved.
    if (event.is_up) return false;

    // Stage 8: excluded applications bypass.
    if (excluded && excluded()) return false;

    // Stage 9: English mode -> optional macro expansion only.
    if (!cfg.vietnamese) {
        if (cfg.macro_enabled && cfg.macro_in_english) {
            return handle_english_macro(event);
        }
        return false;
    }

    // Stage 10: composing.
    return handle_composing(event);
}

void TypingPipeline::set_cleaner_active(bool active) noexcept {
    cleaner_active_ = active;
    cleaner_esc_held_ = false;
}

void TypingPipeline::set_clock(ClockMs clock) {
    clock_ = std::move(clock);
}

std::uint64_t TypingPipeline::now_ms() const {
    if (clock_) return clock_();
    return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch())
            .count());
}

bool TypingPipeline::handle_cleaner(const HookKeyEvent& event) {
    // The cleaner hotkey toggles the cleaner off. Stage 5 never runs while
    // the cleaner is active, so the match happens here; on_action is not
    // invoked because TrayRuntime toggles activation from stage 5 only.
    const uint8_t mods = tracker_.mask() & ~kModCaps;
    if (!event.is_up && hotkeys_.match(event.vk, mods) == HotkeyAction::cleaner) {
        cleaner_active_ = false;
        cleaner_esc_held_ = false;
        return true;
    }

    if (event.vk == kVkEscape) {
        if (event.is_up) {
            cleaner_esc_held_ = false;
        } else if (!cleaner_esc_held_) {
            cleaner_esc_held_ = true;
            cleaner_esc_down_ms_ = now_ms();
        } else if (now_ms() - cleaner_esc_down_ms_ >= kCleanerUnlockHoldMs) {
            cleaner_active_ = false;
            cleaner_esc_held_ = false;
        }
        return true;
    }

    // Any other key cancels the Esc hold (mirrors macOS reset behavior).
    cleaner_esc_held_ = false;
    return true;
}

bool TypingPipeline::handle_composing(const HookKeyEvent& event) {
    const KeyCategory category = KeyClassifier::classify(event.vk);

    // Fast-path 1: function & media keys pass untouched.
    if (category == KeyCategory::function_or_media) return false;

    // Fast-path 2: navigation resets buffers.
    if (category == KeyCategory::navigation) {
        engine_.reset();
        macro_.reset();
        return false;
    }

    engine_.set_caps_state(tracker_.shift(), tracker_.caps_lock());

    // Fast-path 3: backspace.
    if (category == KeyCategory::backspace) {
        macro_.record_backspace();
        const auto result = engine_.backspace();
        if (result.handled) {
            KeyInjector::inject(result.backspaces, result.text);
            return true;
        }
        return false;
    }

    // Fast-path 4: structural word-break keys (Return/Tab, not Space).
    if (category == KeyCategory::word_break && event.vk != kVkSpace) {
        engine_.reset();
        macro_.reset();
        return false;
    }

    const char32_t character = extract_character(event);
    if (character < 32 || character > 126) {
        engine_.reset();
        macro_.reset();
        return false;
    }

    // Space first triggers macro expansion (checks its own enabled flag).
    if (event.vk == kVkSpace) {
        const auto macro_result = macro_.evaluate_on_space();
        if (macro_result.handled) {
            engine_.reset();
            KeyInjector::inject(macro_result.backspaces, macro_result.replacement);
            return true;
        }
    }

    const auto result = engine_.filter(character);
    macro_.record_char(character);
    if (result.handled) {
        KeyInjector::inject(result.backspaces, result.text);
        return true;
    }
    return false;
}

bool TypingPipeline::handle_english_macro(const HookKeyEvent& event) {
    const KeyCategory category = KeyClassifier::classify(event.vk);

    if (category == KeyCategory::navigation || category == KeyCategory::function_or_media) {
        macro_.reset();
        return false;
    }
    if (category == KeyCategory::backspace) {
        macro_.record_backspace();
        return false;
    }
    if (category == KeyCategory::word_break && event.vk != kVkSpace) {
        macro_.reset();
        return false;
    }

    const char32_t character = extract_character(event);
    if (character < 32 || character > 126) {
        macro_.reset();
        return false;
    }

    if (event.vk == kVkSpace) {
        const auto result = macro_.evaluate_on_space();
        if (result.handled) {
            KeyInjector::inject(result.backspaces, result.replacement);
            return true;
        }
        return false;
    }

    macro_.record_char(character);
    return false;
}

#ifdef _WIN32

char32_t TypingPipeline::extract_character(const HookKeyEvent& event) const {
    std::array<uint8_t, 256> state{};
    tracker_.build_key_state(state);
    wchar_t buffer[8]{};
    const HKL layout = GetKeyboardLayout(0);
    const int len = ToUnicodeEx(static_cast<UINT>(event.vk), static_cast<UINT>(event.scan),
                                reinterpret_cast<const BYTE*>(state.data()), buffer, 8, 0,
                                layout);
    if (len <= 0) return 0;
    const wchar_t unit = buffer[0];
    if (unit >= 0xD800 && unit <= 0xDFFF) return 0;
    return static_cast<char32_t>(unit);
}

#else

// Test-only fallback (US layout) so pipeline tests run on all platforms.
char32_t TypingPipeline::extract_character(const HookKeyEvent& event) const {
    const unsigned vk = event.vk;
    if (vk == kVkSpace) return U' ';
    if (vk >= '0' && vk <= '9') return static_cast<char32_t>(vk);
    if (vk >= 'A' && vk <= 'Z') {
        const bool upper = tracker_.shift() != tracker_.caps_lock();
        return static_cast<char32_t>(upper ? vk : vk + ('a' - 'A'));
    }
    const bool shift = tracker_.shift();
    switch (vk) {
    case 0xBA: return shift ? U':' : U';';
    case 0xBB: return shift ? U'+' : U'=';
    case 0xBC: return shift ? U'<' : U',';
    case 0xBD: return shift ? U'_' : U'-';
    case 0xBE: return shift ? U'>' : U'.';
    case 0xBF: return shift ? U'?' : U'/';
    case 0xC0: return shift ? U'~' : U'`';
    case 0xDB: return shift ? U'{' : U'[';
    case 0xDC: return shift ? U'|' : U'\\';
    case 0xDD: return shift ? U'}' : U']';
    case 0xDE: return shift ? U'"' : U'\'';
    default: return 0;
    }
}

#endif

} // namespace skey::windows
