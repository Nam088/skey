#include "../Shared/TsfBridge/TsfBridge.h"
#include "../skey-tray/Pipeline/ForegroundAppTracker.h"
#include "../skey-tray/Pipeline/KeyInjector.h"
#include "../skey-tray/Pipeline/TypingPipeline.h"

#include <cassert>
#include <cstring>
#include <string>
#include <vector>

using namespace skey::windows;

namespace {

struct FakeEngine : EngineInterface {
    bool handle_next = true;
    std::string next_text = "\xc4\x91\xC3\xA1nh";  // "đánh"
    int next_backspaces = 4;
    int filter_calls = 0;
    int backspace_calls = 0;
    int reset_calls = 0;

    void reset() override { ++reset_calls; }
    void set_caps_state(bool, bool) override {}
    Result filter(char32_t) override {
        ++filter_calls;
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

HookKeyEvent down(unsigned vk) {
    return HookKeyEvent{vk, 0, 0, false, false, false};
}

} // namespace

int main() {
    // --- to_wide / to_utf8 round-trips ---
    {
        assert(tsf_bridge::to_wide("").empty());
        assert(tsf_bridge::to_wide("a") == L"a");
        const std::string danh = "\xc4\x91\xC3\xA1nh";  // "đánh"
        const std::wstring wide = tsf_bridge::to_wide(danh);
        assert(wide.size() == 4 && wide[0] == 0x0111 && wide[1] == 0x00E1);
        assert(tsf_bridge::to_utf8(wide) == danh);
        // Surrogate pair (emoji) -> 2 UTF-16 units and back.
        const std::string emoji = "\xF0\x9F\x98\x80";
        const std::wstring emoji_wide = tsf_bridge::to_wide(emoji);
        assert(emoji_wide.size() == 2 && emoji_wide[0] == 0xD83D && emoji_wide[1] == 0xDE00);
        assert(tsf_bridge::to_utf8(emoji_wide) == emoji);
    }

    // --- encode_push / decode_push round-trip ---
    {
        TsfBridgeFrame frame{};
        const std::string text = "\xc4\x91\xC3\xA1nh \xF0\x9F\x98\x80";
        assert(tsf_bridge::encode_push(frame, 7, 1234, 3, text));
        assert(frame.magic == kTsfBridgeMagic && frame.version == kTsfBridgeVersion);
        assert(frame.seq == 7 && frame.type == static_cast<std::uint32_t>(TsfBridgeMsg::push));
        assert(frame.target_pid == 1234 && frame.backspaces == 3);

        int backspaces = 0;
        std::string out;
        assert(tsf_bridge::decode_push(frame, 7, 1234, backspaces, out));
        assert(backspaces == 3 && out == text);
    }

    // --- Backspace-only push (empty replacement text) ---
    {
        TsfBridgeFrame frame{};
        assert(tsf_bridge::encode_push(frame, 2, 7, 5, ""));
        assert(frame.text_len == 0 && frame.backspaces == 5);
        int backspaces = 0;
        std::string out = "sentinel";
        assert(tsf_bridge::decode_push(frame, 2, 7, backspaces, out));
        assert(backspaces == 5 && out.empty());
    }

    // --- Maximum-size text fits exactly ---
    {
        std::string max_text(kTsfMaxTextUnits, 'x');
        TsfBridgeFrame frame{};
        assert(tsf_bridge::encode_push(frame, 1, 1, 0, max_text));
        assert(frame.text_len == kTsfMaxTextUnits);
        int backspaces = 0;
        std::string out;
        assert(tsf_bridge::decode_push(frame, 1, 1, backspaces, out));
        assert(out == max_text);
    }

    // --- Too-long text is rejected (no truncation) ---
    {
        std::string long_text(kTsfMaxTextUnits + 1, 'x');
        TsfBridgeFrame frame{};
        assert(!tsf_bridge::encode_push(frame, 1, 1, 0, long_text));
        // A 4-byte emoji counts as 2 UTF-16 units, so unit accounting must
        // reject kTsfMaxTextUnits/2 + 1 emojis (= kTsfMaxTextUnits + 2 units).
        std::string emojis;
        for (std::size_t i = 0; i < kTsfMaxTextUnits / 2 + 1; ++i) {
            emojis += "\xF0\x9F\x98\x80";
        }
        TsfBridgeFrame emoji_frame{};
        assert(!tsf_bridge::encode_push(emoji_frame, 1, 1, 0, emojis));
    }

    // --- decode_push rejects corrupted/stale frames ---
    {
        TsfBridgeFrame frame{};
        assert(tsf_bridge::encode_push(frame, 42, 99, 2, "abc"));
        int backspaces = 0;
        std::string out;

        // Wrong seq (stale or foreign request).
        assert(!tsf_bridge::decode_push(frame, 41, 99, backspaces, out));
        // Wrong pid (push meant for another process).
        assert(!tsf_bridge::decode_push(frame, 42, 98, backspaces, out));

        // Corrupted magic / version / type.
        TsfBridgeFrame bad_magic = frame;
        bad_magic.magic = 0xDEADBEEF;
        assert(!tsf_bridge::decode_push(bad_magic, 42, 99, backspaces, out));

        TsfBridgeFrame bad_version = frame;
        bad_version.version = kTsfBridgeVersion + 1;
        assert(!tsf_bridge::decode_push(bad_version, 42, 99, backspaces, out));

        TsfBridgeFrame bad_type = frame;
        bad_type.type = static_cast<std::uint32_t>(TsfBridgeMsg::response);
        assert(!tsf_bridge::decode_push(bad_type, 42, 99, backspaces, out));

        // Overlong text_len.
        TsfBridgeFrame bad_len = frame;
        bad_len.text_len = static_cast<std::uint32_t>(kTsfMaxTextUnits + 1);
        assert(!tsf_bridge::decode_push(bad_len, 42, 99, backspaces, out));
    }

    // --- Layout name is CLSID + profile GUID ---
    {
        std::wstring composed = kSKeyTsfClsid;
        composed += kSKeyTsfProfile;
        assert(composed == kSKeyTsfLayoutName);
    }

    // --- is_browser: Chromium family, Firefox, generic forks ---
    {
        assert(ForegroundAppTracker::is_browser("chrome.exe"));
        assert(ForegroundAppTracker::is_browser("msedge"));
        assert(ForegroundAppTracker::is_browser("Brave.EXE"));
        assert(ForegroundAppTracker::is_browser("firefox.exe"));
        assert(ForegroundAppTracker::is_browser("chrome_proxy.exe"));
        assert(ForegroundAppTracker::is_browser("C:\\Program Files\\Chrome\\chrome.exe"));
        // Generic Chromium forks via the "browser" suffix.
        assert(ForegroundAppTracker::is_browser("avastbrowser.exe"));
        assert(ForegroundAppTracker::is_browser("ybrowser"));
        assert(ForegroundAppTracker::is_browser("browser"));
        // Not browsers.
        assert(!ForegroundAppTracker::is_browser("notepad.exe"));
        assert(!ForegroundAppTracker::is_browser("code.exe"));
        assert(!ForegroundAppTracker::is_browser("explorer.exe"));
        assert(!ForegroundAppTracker::is_browser(""));
        assert(!ForegroundAppTracker::is_browser("chrom"));
    }

    // --- Pipeline routes engine edits through the TSF pusher ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        std::vector<std::pair<int, std::string>> pushed;
        bool pusher_result = true;
        pipe.set_tsf_pusher([&](int backspaces, const std::string& text) {
            pushed.emplace_back(backspaces, text);
            return pusher_result;
        });

        // Type "d" (VK 'D' = 0x44) -> engine handled -> pusher receives edit.
        assert(pipe.process(down(0x44)));
        assert(pushed.size() == 1);
        assert(pushed[0].first == engine.next_backspaces);
        assert(pushed[0].second == engine.next_text);
        assert(engine.filter_calls == 1);

        // Pusher fails (DLL absent) -> key still swallowed; the SendInput
        // fallback runs inside deliver() and is a no-op in tests.
        pusher_result = false;
        assert(pipe.process(down(0x44)));
        assert(pushed.size() == 2);

        // Backspace fast-path also goes through deliver().
        engine.handle_next = true;
        assert(pipe.process(down(0x08)));
        assert(pushed.size() == 3);
        assert(pushed[2].first == 0 && pushed[2].second.empty());
    }

    // --- No pusher installed -> plain SendInput path (compiles + swallows) ---
    {
        FakeEngine engine;
        MacroEngine macro;
        TypingPipeline pipe(engine, macro, nullptr);
        assert(pipe.process(down(0x44)));
        assert(engine.filter_calls == 1);
    }

    return 0;
}
