#include "../skey-ime/Host/CompositionHost.h"

#include <cassert>
#include <string>

using namespace skey::windows;

struct FakeEngine final : IEngine {
    EditResult next{};
    int resets{0};
    EditResult filter(std::uint32_t) override { return next; }
    EditResult backspace() override { return next; }
    void reset() override { ++resets; }
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
    return 0;
}
