#include "../skey-ime/Host/CompositionHost.h"

#include <cassert>
#include <string>

using namespace skey::windows;

struct FakeEngine final : IEngine {
    EditResult next{};
    EditResult backspace_result{};
    int resets{0};
    int caps_calls{0};
    bool last_shift{false};
    bool last_caps{false};
    EditResult filter(std::uint32_t) override { return next; }
    EditResult backspace() override { return backspace_result; }
    void reset() override { ++resets; }
    void set_caps_state(bool shift, bool caps) override {
        ++caps_calls;
        last_shift = shift;
        last_caps = caps;
    }
};

struct FakeHost final : ITextHost {
    std::string text;
    unsigned deleted{0};
    int commits{0};
    int resets{0};
    bool reject_insert{false};
    bool delete_previous(unsigned count) override { deleted += count; return true; }
    bool insert_text(std::string_view value) override {
        if (reject_insert) return false;
        text.append(value);
        return true;
    }
    bool replace_selection(std::string_view value) override { text.assign(value); return true; }
    void commit() override { ++commits; }
    void reset() override { ++resets; }
};

int main() {
    FakeEngine engine;
    FakeHost host;
    CompositionHost adapter(engine, host);

    engine.next = {.handled = true, .backspaces = 2, .text = "đ", .committed = false, .reset = false};
    const auto edit = adapter.dispatch({EventKind::key_down, 'd', 0, 0, false});
    assert(edit.handled && edit.backspaces == 2);
    assert(host.deleted == 2 && host.text == "đ");

    engine.next = {.handled = false};
    const auto pass = adapter.dispatch({EventKind::key_down, 'x', 0, 0, false});
    assert(!pass.handled && host.text == "đ");

    const auto reset = adapter.dispatch({EventKind::focus_changed});
    assert(!reset.handled && reset.reset && engine.resets == 1 && host.resets == 1);

    engine.next = {.handled = true, .backspaces = 1, .text = "x"};
    host.reject_insert = true;
    const auto rejected = adapter.dispatch({EventKind::key_down, 'x', 0, 0, false});
    assert(!rejected.handled && rejected.reset && engine.resets == 2 && host.resets == 2);
    host.reject_insert = false;

    engine.next = {.handled = true, .text = " "};
    const auto word = adapter.dispatch({EventKind::word_break, ' ', 0, 0, false});
    assert(word.committed && word.reset && host.commits == 1);

    engine.backspace_result = {.handled = true, .backspaces = 1, .text = "a"};
    host.text.clear();
    host.deleted = 0;
    const auto bs = adapter.dispatch({EventKind::backspace, 0, 0x08, 0, false});
    assert(bs.handled && host.deleted == 1 && host.text == "a");

    engine.resets = 0;
    host.resets = 0;
    adapter.dispatch({EventKind::navigation, 0, 0x25, 0, false});
    assert(engine.resets == 1 && host.resets == 1);

    adapter.dispatch({EventKind::app_changed, 0, 0, 0, false});
    assert(engine.resets == 2 && host.resets == 2);

    adapter.dispatch({EventKind::reset, 0, 0, 0, false});
    assert(engine.resets == 3 && host.resets == 3);

    engine.caps_calls = 0;
    engine.next = {.handled = true, .text = "A"};
    adapter.dispatch({EventKind::key_down, 'a', 'A', 1, false});
    assert(engine.caps_calls == 1 && engine.last_shift == true && engine.last_caps == false);

    adapter.dispatch({EventKind::key_down, 'a', 'A', 8, false});
    assert(engine.caps_calls == 2 && engine.last_shift == false && engine.last_caps == true);

    host.reject_insert = false;
    return 0;
}
