#include "CompositionHost.h"

namespace skey::windows {

EditResult CompositionHost::dispatch(const KeyEvent& event) {
    const bool shift = (event.modifiers & 1) != 0;
    const bool caps = (event.modifiers & 8) != 0;

    switch (event.kind) {
    case EventKind::key_down:
        engine_.set_caps_state(shift, caps);
        return apply_edit(engine_.filter(event.codepoint));
    case EventKind::backspace:
        return apply_edit(engine_.backspace());
    case EventKind::word_break: {
        engine_.set_caps_state(shift, caps);
        const auto result = apply_edit(engine_.filter(event.codepoint));
        host_.commit();
        reset();
        auto committed = result;
        committed.committed = true;
        committed.reset = true;
        return committed;
    }
    case EventKind::navigation:
    case EventKind::focus_changed:
    case EventKind::app_changed:
    case EventKind::reset:
        reset();
        return EditResult{.handled = false, .reset = true};
    }
    return {};
}

EditResult CompositionHost::apply_edit(EditResult result) {
    if (!result.handled) {
        return result;
    }

    if (result.backspaces > 0 && !host_.delete_previous(result.backspaces)) {
        reset();
        return EditResult{.handled = false, .reset = true};
    }
    if (!result.text.empty() && !host_.insert_text(result.text)) {
        reset();
        return EditResult{.handled = false, .reset = true};
    }
    return result;
}

void CompositionHost::reset() {
    engine_.reset();
    host_.reset();
}

} // namespace skey::windows
