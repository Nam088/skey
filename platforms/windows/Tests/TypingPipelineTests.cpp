#include "../skey-tray/Pipeline/HotkeyManager.h"
#include "../skey-tray/Pipeline/KeyInjector.h"
#include "../skey-tray/Pipeline/TypingPipeline.h"

#include <cassert>
#include <vector>

using namespace skey::windows;

namespace {

struct FakeEngine : EngineInterface {
    bool handle_next = true;
    std::string next_text = "x";
    int next_backspaces = 1;
    int filter_calls = 0;
    int backspace_calls = 0;
    int reset_calls = 0;
    bool shift = false;
    bool caps = false;
    char32_t last_char = 0;

    void reset() override { ++reset_calls; }
    void set_caps_state(bool s, bool c) override { shift = s; caps = c; }
    Result filter(char32_t ch) override {
        ++filter_calls;
        last_char = ch;
        if (!handle_next) return {};
        return {true, next_backspaces, next_text};
    }
    Result backspace() override {
        ++backspace_calls;
        if (!handle_next) return {};
        return {true, 0, ""};
    }
    Result restore() override { return {}; }
};

HookKeyEvent down(unsigned vk, bool injected = false, bool extended = false) {
    return HookKeyEvent{vk, 0, 0, false, injected, extended};
}

HookKeyEvent up(unsigned vk) {
    return HookKeyEvent{vk, 0, 0, true, false, false};
}

} // namespace

int main() {
    // --- Stage 1: injected events always pass ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(!pipe.process(down('A', /*injected=*/true)));
        assert(engine.filter_calls == 0);
    }

    // --- Stage 2: hook disabled passes everything ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        TypingPipeline::Config cfg;
        cfg.hook_enabled = false;
        pipe.set_config(cfg);
        assert(!pipe.process(down('A')));
        assert(engine.filter_calls == 0);
    }

    // --- Stage 5: Alt+Z hotkey swallows down+up and fires the action ---
    {
        FakeEngine engine;
        MacroEngine macro;
        std::vector<HotkeyAction> fired;
        TypingPipeline pipe(engine, macro,
                            [&](HotkeyAction a) { fired.push_back(a); });
        pipe.process(down(0x12));  // Alt down (modifier: passes)
        assert(pipe.process(down('Z')));
        assert(fired.size() == 1 && fired[0] == HotkeyAction::toggle_language);
        assert(pipe.process(up('Z')));  // key-up swallowed too
        assert(fired.size() == 1);      // but no second fire
        assert(engine.filter_calls == 0);
    }

    // --- Stage 6: Ctrl combos reset engines and pass ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.process(down('A'));  // compose something first
        const int resets_before = engine.reset_calls;
        pipe.process(down(0xA2));  // Ctrl down
        assert(!pipe.process(down('C')));
        assert(engine.reset_calls == resets_before + 1);
        assert(engine.filter_calls == 1);  // C never reached the engine
    }

    // --- Stage 10: composing filters characters and swallows handled edits ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(pipe.process(down('A')));
        assert(engine.filter_calls == 1);
        assert(engine.last_char == U'a');
        assert(!engine.shift);

        engine.handle_next = false;
        assert(!pipe.process(down('B')));  // engine passed -> key passes
        assert(engine.filter_calls == 2);
    }

    // --- Caps state sync: Shift+A filters uppercase ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.process(down(0xA0));  // LShift down
        assert(pipe.process(down('A')));
        assert(engine.last_char == U'A');
        assert(engine.shift);
    }

    // --- CapsLock flips letter case ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.process(down(0x14));  // CapsLock down (toggles on)
        pipe.process(up(0x14));
        assert(pipe.process(down('A')));
        assert(engine.last_char == U'A');
    }

    // --- Backspace: engine handled -> swallow, unhandled -> pass ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(pipe.process(down(0x08)));
        assert(engine.backspace_calls == 1);
        engine.handle_next = false;
        assert(!pipe.process(down(0x08)));
        assert(engine.backspace_calls == 2);
    }

    // --- Navigation resets engines and passes ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(!pipe.process(down(0x25)));  // VK_LEFT
        assert(engine.reset_calls == 1);
        assert(engine.filter_calls == 0);
    }

    // --- Word breaks (Return/Tab) reset and pass ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(!pipe.process(down(0x0D)));
        assert(engine.reset_calls == 1);
        assert(!pipe.process(down(0x09)));
        assert(engine.reset_calls == 2);
    }

    // --- Function keys pass untouched ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(!pipe.process(down(0x74)));  // F5
        assert(engine.filter_calls == 0 && engine.reset_calls == 0);
    }

    // --- Key-up passes and preserves engine state ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(!pipe.process(up('A')));
        assert(engine.filter_calls == 0);
    }

    // --- Stage 9: English mode passes characters (no macro) ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        TypingPipeline::Config cfg;
        cfg.vietnamese = false;
        pipe.set_config(cfg);
        assert(!pipe.process(down('A')));
        assert(engine.filter_calls == 0);
    }

    // --- Stage 9: English mode + macro expansion ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        TypingPipeline::Config cfg;
        cfg.vietnamese = false;
        cfg.macro_enabled = true;
        cfg.macro_in_english = true;
        pipe.set_config(cfg);
        macro.set_enabled(true);
        macro.reload({{"btw", "by the way"}});
        assert(!pipe.process(down('B')));
        assert(!pipe.process(down('T')));
        assert(!pipe.process(down('W')));
        assert(pipe.process(down(0x20)));  // Space triggers expansion
        assert(engine.filter_calls == 0);
    }

    // --- Excluded apps bypass ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.set_excluded_app_provider([] { return true; });
        assert(!pipe.process(down('A')));
        assert(engine.filter_calls == 0);
    }

    // --- Stage 3: mouse click resets engines + macro + chord ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.on_mouse_click();
        assert(engine.reset_calls == 1);
    }

    // --- Stage 4: modifier-only chord fires toggle on full release ---
    {
        FakeEngine engine;
        MacroEngine macro;
        std::vector<HotkeyAction> fired;
        TypingPipeline pipe(engine, macro,
                            [&](HotkeyAction a) { fired.push_back(a); });
        pipe.hotkeys().set_hotkey(HotkeyAction::toggle_language,
                                  Hotkey{0, static_cast<uint8_t>(kModCtrl | kModShift)});
        pipe.process(down(0xA2));  // Ctrl down: subset, not armed
        assert(fired.empty());
        pipe.process(down(0xA0));  // Shift down: exact match, armed
        assert(fired.empty());
        pipe.process(up(0xA0));    // release one: still armed
        assert(fired.empty());
        pipe.process(up(0xA2));    // release all: fire
        assert(fired.size() == 1 && fired[0] == HotkeyAction::toggle_language);

        // Intervening regular key cancels the chord.
        pipe.process(down(0xA2));
        pipe.process(down(0xA0));
        pipe.process(down('A'));
        pipe.process(up('A'));
        pipe.process(up(0xA0));
        pipe.process(up(0xA2));
        assert(fired.size() == 1);
    }

    // --- Macro on Space inside Vietnamese mode ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        macro.set_enabled(true);
        macro.reload({{"ko", "không"}});
        assert(pipe.process(down('K')));
        assert(pipe.process(down('O')));
        assert(pipe.process(down(0x20)));  // macro hit -> swallowed
        // Non-macro space still goes to the engine.
        engine.handle_next = false;
        assert(!pipe.process(down(0x20)));
        assert(engine.filter_calls >= 1);
    }

    // --- KeyInjector UTF-8 -> UTF-16 conversion ---
    {
        const auto a = KeyInjector::utf8_to_utf16("a");
        assert(a.size() == 1 && a[0] == 0x61);
        const auto danh = KeyInjector::utf8_to_utf16("\xc4\x91\xC3\xA1nh");  // "đánh"
        assert(danh.size() == 4 && danh[0] == 0x0111 && danh[1] == 0x00E1);
        const auto emoji = KeyInjector::utf8_to_utf16("\xF0\x9F\x98\x80");
        assert(emoji.size() == 2 && emoji[0] == 0xD83D && emoji[1] == 0xDE00);
        const auto empty = KeyInjector::utf8_to_utf16("");
        assert(empty.empty());
    }

    return 0;
}
