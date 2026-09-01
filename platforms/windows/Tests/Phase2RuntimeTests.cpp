#include "../skey-tray/Pipeline/ForegroundAppTracker.h"
#include "../skey-tray/Pipeline/HotkeyManager.h"
#include "../skey-tray/Pipeline/TypingPipeline.h"

#include <cassert>
#include <vector>

using namespace skey::windows;

namespace {

struct FakeEngine : EngineInterface {
    bool restore_handled = true;
    int restore_calls = 0;
    int filter_calls = 0;

    void reset() override {}
    void set_caps_state(bool, bool) override {}
    Result filter(char32_t) override {
        ++filter_calls;
        return {};
    }
    Result backspace() override { return {}; }
    Result restore() override {
        ++restore_calls;
        if (!restore_handled) return {};
        return {true, 2, "aw"};
    }
};

HookKeyEvent down(unsigned vk) {
    return HookKeyEvent{vk, 0, 0, false, false, false};
}

HookKeyEvent up(unsigned vk) {
    return HookKeyEvent{vk, 0, 0, true, false, false};
}

constexpr unsigned kVkCtrl = 0x11;
constexpr unsigned kVkShift = 0x10;
constexpr unsigned kVkEsc = 0x1B;

} // namespace

int main() {
    // --- HotkeyManager: settings records override defaults ---
    {
        assert(HotkeyManager::action_from_name("toggleLanguage") == HotkeyAction::toggle_language);
        assert(HotkeyManager::action_from_name("clipboard") == HotkeyAction::clipboard);
        assert(HotkeyManager::action_from_name("cleaner") == HotkeyAction::cleaner);
        assert(HotkeyManager::action_from_name("ai") == HotkeyAction::ai);
        assert(HotkeyManager::action_from_name("translate") == HotkeyAction::translate);
        assert(HotkeyManager::action_from_name("bogus") == HotkeyAction::none);

        HotkeyManager manager;
        // Defaults: Alt+Z toggles language.
        assert(manager.match(0x5A, kModAlt) == HotkeyAction::toggle_language);

        std::vector<HotkeyRecord> records{
            {"toggleLanguage", 0x51, kModCtrl},            // Ctrl+Q
            {"clipboard", 0x43, static_cast<unsigned>(kModCtrl | kModShift)},
            {"unknownAction", 0x58, kModAlt},
        };
        manager.apply_records(records);
        assert(manager.match(0x51, kModCtrl) == HotkeyAction::toggle_language);
        assert(manager.match(0x43, static_cast<uint8_t>(kModCtrl | kModShift)) == HotkeyAction::clipboard);
        // Old binding replaced, unknown action ignored.
        assert(manager.match(0x5A, kModAlt) == HotkeyAction::none);
        assert(manager.match(0x58, kModAlt) == HotkeyAction::none);

        // Modifier-only language chord via settings record.
        std::vector<HotkeyRecord> mod_only{{"toggleLanguage", 0, static_cast<unsigned>(kModCtrl | kModShift)}};
        manager.apply_records(mod_only);
        assert(manager.language_is_modifier_only());
        assert(manager.language_modifiers() == (kModCtrl | kModShift));
    }

    // --- TypingPipeline stage 5b: Ctrl+Shift+Esc restore ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.process(down(kVkCtrl));
        pipe.process(down(kVkShift));
        assert(pipe.process(down(kVkEsc)));  // handled restore -> swallow
        assert(engine.restore_calls == 1);
    }
    {
        FakeEngine engine;
        engine.restore_handled = false;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        pipe.process(down(kVkCtrl));
        pipe.process(down(kVkShift));
        // Nothing to restore: chord passes so Task Manager still works.
        assert(!pipe.process(down(kVkEsc)));
        assert(engine.restore_calls == 1);
    }
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        TypingPipeline::Config cfg = pipe.config();
        cfg.restore_enabled = false;
        pipe.set_config(cfg);
        pipe.process(down(kVkCtrl));
        pipe.process(down(kVkShift));
        assert(!pipe.process(down(kVkEsc)));
        assert(engine.restore_calls == 0);
    }

    // --- ForegroundAppTracker: normalize / excluded / developer tools ---
    {
        assert(ForegroundAppTracker::normalize("C:\\Program Files\\Mozilla Firefox\\firefox.exe") == "firefox");
        assert(ForegroundAppTracker::normalize("CHROME.EXE") == "chrome");
        assert(ForegroundAppTracker::normalize("notepad") == "notepad");

        const std::vector<std::string> excluded{"chrome.exe", "msedge.exe"};
        assert(ForegroundAppTracker::is_excluded("chrome.exe", excluded));
        assert(ForegroundAppTracker::is_excluded("CHROME", excluded));
        assert(ForegroundAppTracker::is_excluded("C:\\x\\msedge.exe", excluded));
        assert(!ForegroundAppTracker::is_excluded("firefox.exe", excluded));
        assert(!ForegroundAppTracker::is_excluded("chrome.exe", {}));
        assert(!ForegroundAppTracker::is_excluded("", excluded));

        assert(ForegroundAppTracker::is_developer_tool("code.exe"));
        assert(ForegroundAppTracker::is_developer_tool("Code - Insiders.exe"));
        assert(ForegroundAppTracker::is_developer_tool("idea64.exe"));
        assert(ForegroundAppTracker::is_developer_tool("C:\\x\\WindowsTerminal.exe"));
        assert(ForegroundAppTracker::is_developer_tool("cmd"));
        assert(ForegroundAppTracker::is_developer_tool("pwsh.exe"));
        assert(!ForegroundAppTracker::is_developer_tool("notepad.exe"));
        assert(!ForegroundAppTracker::is_developer_tool("winword.exe"));
        assert(!ForegroundAppTracker::is_developer_tool(""));
    }

    // --- Excluded apps bypass composing in the pipeline ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        bool excluded = true;
        pipe.set_excluded_app_provider([&] { return excluded; });
        assert(!pipe.process(down('A')));
        assert(engine.filter_calls == 0);
        excluded = false;
        assert(!pipe.process(down('A')));
        assert(engine.filter_calls == 1);
    }

    // --- Cleaner: every key blocked, Esc held 2s unlocks ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        std::uint64_t now = 0;
        pipe.set_clock([&] { return now; });

        pipe.set_cleaner_active(true);
        assert(pipe.cleaner_active());
        assert(pipe.process(down('A')));      // swallowed
        assert(engine.filter_calls == 0);
        assert(pipe.process(down(kVkCtrl)));  // modifiers blocked too
        pipe.process(up(kVkCtrl));            // release so stage 6 stays clear

        // Esc hold: first down starts the timer, auto-repeat at +2000ms unlocks.
        assert(pipe.process(down(kVkEsc)));
        assert(pipe.cleaner_active());
        now = 1000;
        assert(pipe.process(down(kVkEsc)));
        assert(pipe.cleaner_active());
        now = 2000;
        assert(pipe.process(down(kVkEsc)));
        assert(!pipe.cleaner_active());
        assert(!pipe.process(down('A')));  // normal processing resumes
        assert(engine.filter_calls == 1);
    }
    {
        // Any other key resets the Esc hold.
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        std::uint64_t now = 0;
        pipe.set_clock([&] { return now; });
        pipe.set_cleaner_active(true);

        pipe.process(down(kVkEsc));
        now = 1500;
        pipe.process(down('X'));     // resets the hold
        now = 1600;
        pipe.process(down(kVkEsc));  // hold restarts here
        now = 3000;
        pipe.process(down(kVkEsc));
        assert(pipe.cleaner_active());  // only 1400ms into the new hold
        now = 3600;
        pipe.process(down(kVkEsc));
        assert(!pipe.cleaner_active());
    }
    {
        // Hotkey toggles ON via the stage-5 callback, OFF internally.
        FakeEngine engine;
        MacroEngine macro;
        std::vector<HotkeyAction> actions;
        TypingPipeline pipe(engine, macro, [&](HotkeyAction action) { actions.push_back(action); });
        constexpr unsigned kVkAlt = 0x12;

        pipe.process(down(kVkAlt));
        pipe.process(down(kVkShift));
        assert(pipe.process(down(HotkeyManager::kVkK)));  // Alt+Shift+K swallowed
        assert(actions.size() == 1 && actions.back() == HotkeyAction::cleaner);

        pipe.set_cleaner_active(true);
        pipe.process(down(kVkAlt));
        pipe.process(down(kVkShift));
        assert(pipe.process(down(HotkeyManager::kVkK)));
        assert(!pipe.cleaner_active());
        assert(actions.size() == 1);  // no duplicate callback on internal unlock
    }

    // --- Cleaner listener events feed the overlay ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        std::uint64_t now = 0;
        pipe.set_clock([&] { return now; });
        std::vector<std::pair<TypingPipeline::CleanerEvent, std::uint64_t>> events;
        pipe.set_cleaner_listener([&](TypingPipeline::CleanerEvent event, std::uint64_t ms) {
            events.emplace_back(event, ms);
        });

        pipe.set_cleaner_active(true);   // activated @0
        pipe.process(down(kVkEsc));      // esc_down @0
        now = 500;
        pipe.process(down('X'));         // other_key resets the hold
        now = 800;
        pipe.process(down(kVkEsc));      // esc_down @800
        now = 900;
        pipe.process(up(kVkEsc));        // esc_up
        now = 1000;
        pipe.process(down(kVkEsc));      // esc_down @1000
        now = 3000;
        pipe.process(down(kVkEsc));      // hold complete -> deactivated
        assert(!pipe.cleaner_active());

        assert(events.size() == 7);
        assert(events[0].first == TypingPipeline::CleanerEvent::activated);
        assert(events[1].first == TypingPipeline::CleanerEvent::esc_down && events[1].second == 0);
        assert(events[2].first == TypingPipeline::CleanerEvent::other_key && events[2].second == 500);
        assert(events[3].first == TypingPipeline::CleanerEvent::esc_down && events[3].second == 800);
        assert(events[4].first == TypingPipeline::CleanerEvent::esc_up);
        assert(events[5].first == TypingPipeline::CleanerEvent::esc_down && events[5].second == 1000);
        assert(events[6].first == TypingPipeline::CleanerEvent::deactivated && events[6].second == 3000);

        // No duplicate events for no-op state changes.
        pipe.set_cleaner_active(false);
        assert(events.size() == 7);
    }

    return 0;
}
