#include "../skey-ime/TSF/KeyEventClassifier.h"

#include <cassert>

using namespace skey::windows;

int main() {
    assert(classify_event_kind(0x08) == EventKind::backspace);

    assert(classify_event_kind(0x20) == EventKind::word_break);
    assert(classify_event_kind(0x0D) == EventKind::word_break);
    assert(classify_event_kind(0x09) == EventKind::word_break);

    assert(classify_event_kind(0x1B) == EventKind::navigation);
    assert(classify_event_kind(0x25) == EventKind::navigation);
    assert(classify_event_kind(0x26) == EventKind::navigation);
    assert(classify_event_kind(0x27) == EventKind::navigation);
    assert(classify_event_kind(0x28) == EventKind::navigation);
    assert(classify_event_kind(0x24) == EventKind::navigation);
    assert(classify_event_kind(0x23) == EventKind::navigation);
    assert(classify_event_kind(0x21) == EventKind::navigation);
    assert(classify_event_kind(0x22) == EventKind::navigation);

    assert(classify_event_kind('A') == EventKind::key_down);
    assert(classify_event_kind('Z') == EventKind::key_down);
    assert(classify_event_kind('0') == EventKind::key_down);
    assert(classify_event_kind('9') == EventKind::key_down);
    assert(classify_event_kind(0xC0) == EventKind::key_down);

    assert(pack_modifiers(false, false, false, false) == 0u);
    assert(pack_modifiers(true, false, false, false) == 1u);
    assert(pack_modifiers(false, true, false, false) == 2u);
    assert(pack_modifiers(false, false, true, false) == 4u);
    assert(pack_modifiers(false, false, false, true) == 8u);
    assert(pack_modifiers(true, true, true, true) == 15u);
    assert(pack_modifiers(true, false, true, false) == 5u);

    return 0;
}
