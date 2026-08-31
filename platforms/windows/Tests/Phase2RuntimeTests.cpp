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

    return 0;
}
