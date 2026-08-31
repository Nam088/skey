#include "../skey-ime/EventHandling/Pipeline/WindowsKeyPipeline.h"
#include "../skey-ime/Host/CompositionHost.h"

#include <cassert>
#include <string>

using namespace skey::windows;

struct FakeEngine final : IEngine {
    EditResult next{};
    int resets{0};
    int caps_calls{0};
    bool last_shift{false};
    bool last_caps{false};
    EditResult filter(std::uint32_t) override { return next; }
    EditResult backspace() override { return next; }
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
    bool delete_previous(unsigned count) override { deleted += count; return true; }
    bool insert_text(std::string_view value) override { text.append(value); return true; }
    bool replace_selection(std::string_view value) override { text.assign(value); return true; }
    void commit() override { ++commits; }
    void reset() override { ++resets; }
};

int main() {
    FakeEngine engine;
    FakeHost host;
    CompositionHost composition(engine, host);
    WindowsKeyPipeline pipeline(composition);

    assert(pipeline.test({EventKind::key_down, 'a', 0, 0, false}));
    assert(pipeline.test({EventKind::backspace, 0, 0x08, 0, false}));
    assert(!pipeline.test({EventKind::navigation, 0, 0x25, 0, false}));
    assert(!pipeline.test({EventKind::word_break, ' ', 0x20, 0, false}));
    assert(!pipeline.test({EventKind::focus_changed, 0, 0, 0, false}));

    engine.next = {.handled = true, .backspaces = 1, .text = "á"};
    assert(pipeline.handle({EventKind::key_down, 'a', 'A', 0, false}));
    assert(host.text == "á");
    assert(host.deleted == 1);

    engine.next = {.handled = false};
    assert(!pipeline.handle({EventKind::key_down, 'x', 'X', 0, false}));

    pipeline.focus_changed();
    assert(engine.resets == 1);
    assert(host.resets == 1);

    engine.next = {.handled = true, .backspaces = 2, .text = "đ"};
    assert(pipeline.handle({EventKind::key_down, 'd', 'D', 9, false}));
    assert(engine.caps_calls >= 1);
    assert(engine.last_shift == true);
    assert(engine.last_caps == true);

    return 0;
}
