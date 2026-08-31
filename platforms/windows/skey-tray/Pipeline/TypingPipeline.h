#pragma once

#include <cstdint>
#include <functional>
#include <mutex>

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

    TypingPipeline(EngineInterface& engine, MacroEngine& macro, ActionCallback on_action);

    // Returns true to swallow the event, false to pass it through.
    bool process(const HookKeyEvent& event);

    // Stage 3: mouse button down resets composing + macro state.
    void on_mouse_click();

    void set_config(const Config& config);
    Config config() const;
    void set_excluded_app_provider(ExcludedAppProvider provider);
    HotkeyManager& hotkeys() { return hotkeys_; }

    ModifierTracker& modifiers() { return tracker_; }

private:
    bool handle_composing(const HookKeyEvent& event);
    bool handle_english_macro(const HookKeyEvent& event);
    char32_t extract_character(const HookKeyEvent& event) const;

    EngineInterface& engine_;
    MacroEngine& macro_;
    ActionCallback on_action_;
    HotkeyManager hotkeys_;
    ModifierTracker tracker_;
    bool modifier_only_candidate_ = false;

    mutable std::mutex config_mutex_;
    Config config_;
    ExcludedAppProvider excluded_app_provider_;
};

} // namespace skey::windows
