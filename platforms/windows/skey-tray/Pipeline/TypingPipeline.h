#pragma once

#include <cstdint>
#include <functional>
#include <mutex>
#include <string>

#include "../Engine/EngineInterface.h"
#include "../Engine/MacroEngine.h"
#include "../Hook/HookKeyEvent.h"
#include "../Hook/KeyClassifier.h"
#include "../Hook/ModifierTracker.h"
#include "HotkeyManager.h"

namespace skey::windows {

// 10-stage event processing pipeline, ported 1:1 from the macOS
// TypingPipeline.swift stage order:
//   1. Injected (self) events pass
//   2. Hook disabled -> pass
//   3. Mouse clicks reset engines (handled via on_mouse_click())
//   3b. Keyboard Cleaner: block all keys, Esc hold 2s unlocks
//   4. Modifier-only chord toggle (e.g. Ctrl+Shift)
//   5. Hotkeys swallow (language / clipboard / cleaner / AI / translate)
//   5b. Ctrl+Shift+Esc swallowed-key restore (skey_engine_restore)
//   6. Ctrl/Alt/Win combos -> reset engines, pass
//   7. Key-up -> pass (engine state preserved)
//   8. Excluded apps -> pass
//   9. English mode -> macro expansion only
//  10. Composing: classify, caps sync, engine filter/backspace, inject
class TypingPipeline {
public:
    struct Config {
        bool vietnamese = true;
        bool hook_enabled = true;
        bool macro_enabled = false;
        bool macro_in_english = false;
        bool cleaner_enabled = true;
        bool restore_enabled = true;
    };

    using ActionCallback = std::function<void(HotkeyAction)>;
    using ExcludedAppProvider = std::function<bool()>;
    using ClockMs = std::function<std::uint64_t()>;
    // Phase 5: delivers an engine result through the TSF bridge when the
    // foreground app is a browser. Returning true means the DLL applied the
    // edit; returning false makes the pipeline fall back to SendInput.
    using TsfPusher = std::function<bool(int backspaces, const std::string& utf8_text)>;

    // Progress notifications for the cleaner HUD overlay. Timestamps use the
    // pipeline clock (set_clock). Called from the hook thread; keep it cheap.
    enum class CleanerEvent : std::uint8_t { activated, deactivated, esc_down, esc_up, other_key };
    using CleanerListener = std::function<void(CleanerEvent, std::uint64_t clock_ms)>;

    TypingPipeline(EngineInterface& engine, MacroEngine& macro, ActionCallback on_action);

    // Returns true to swallow the event, false to pass it through.
    bool process(const HookKeyEvent& event);

    // Stage 3: mouse button down resets composing + macro state.
    void on_mouse_click();

    void set_config(const Config& config);
    Config config() const;
    void set_excluded_app_provider(ExcludedAppProvider provider);
    void set_tsf_pusher(TsfPusher pusher);
    HotkeyManager& hotkeys() { return hotkeys_; }

    // Keyboard Cleaner: while active every key is swallowed except the
    // cleaner hotkey (stage 5) and Esc held for 2s, which unlocks.
    void set_cleaner_active(bool active) noexcept;
    bool cleaner_active() const noexcept { return cleaner_active_; }
    static constexpr std::uint64_t kCleanerUnlockHoldMs = 2000;
    void set_clock(ClockMs clock);
    void set_cleaner_listener(CleanerListener listener);

    ModifierTracker& modifiers() { return tracker_; }

private:
    bool handle_cleaner(const HookKeyEvent& event);
    std::uint64_t now_ms() const;
    bool handle_composing(const HookKeyEvent& event);
    bool handle_english_macro(const HookKeyEvent& event);
    char32_t extract_character(const HookKeyEvent& event) const;
    // TSF bridge first (browsers), SendInput fallback everywhere else.
    void deliver(int backspaces, const std::string& utf8_text);

    EngineInterface& engine_;
    MacroEngine& macro_;
    ActionCallback on_action_;
    HotkeyManager hotkeys_;
    ModifierTracker tracker_;
    bool modifier_only_candidate_ = false;
    bool cleaner_active_ = false;
    bool cleaner_esc_held_ = false;
    std::uint64_t cleaner_esc_down_ms_ = 0;
    ClockMs clock_;
    CleanerListener cleaner_listener_;
    TsfPusher tsf_pusher_;

    mutable std::mutex config_mutex_;
    Config config_;
    ExcludedAppProvider excluded_app_provider_;
};

} // namespace skey::windows
