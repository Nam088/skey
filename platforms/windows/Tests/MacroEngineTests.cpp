#include "../skey-tray/Engine/MacroEngine.h"

#include <cassert>

using namespace skey::windows;

int main() {
    MacroEngine macro;
    macro.reload({{"dd", "đã"}, {"vn", "Việt Nam"}});

    // Disabled by default: space evaluates to unhandled and clears the buffer.
    macro.record_char(U'd');
    macro.record_char(U'd');
    auto result = macro.evaluate_on_space();
    assert(!result.handled);

    macro.set_enabled(true);

    // Simple expansion: backspaces equal typed word length, replacement + space.
    macro.record_char(U'd');
    macro.record_char(U'd');
    result = macro.evaluate_on_space();
    assert(result.handled);
    assert(result.backspaces == 2);
    assert(result.replacement == "đã ");

    // Case-insensitive lookup.
    macro.record_char(U'V');
    macro.record_char(U'N');
    result = macro.evaluate_on_space();
    assert(result.handled);
    assert(result.backspaces == 2);
    assert(result.replacement == "Việt Nam ");

    // Unknown word passes through and the buffer is cleared.
    macro.record_char(U'x');
    macro.record_char(U'y');
    result = macro.evaluate_on_space();
    assert(!result.handled);
    macro.record_char(U'd');
    macro.record_char(U'd');
    result = macro.evaluate_on_space();
    assert(result.handled);

    // Backspace edits the word buffer.
    macro.record_char(U'v');
    macro.record_char(U'x');
    macro.record_backspace();
    macro.record_char(U'n');
    result = macro.evaluate_on_space();
    assert(result.handled && result.replacement == "Việt Nam ");

    // Auto-caps: ALL-CAPS typed -> uppercased replacement.
    macro.set_auto_caps(true);
    macro.record_char(U'V');
    macro.record_char(U'N');
    result = macro.evaluate_on_space();
    assert(result.handled);
    assert(result.replacement == "VIệT NAM ");  // ASCII letters uppercased only

    // Auto-caps: capitalized typed -> capitalized replacement.
    macro.record_char(U'V');
    macro.record_char(U'n');
    result = macro.evaluate_on_space();
    assert(result.handled);
    assert(result.replacement == "Việt Nam ");

    // Auto-caps: lowercase typed -> raw replacement.
    macro.record_char(U'v');
    macro.record_char(U'n');
    result = macro.evaluate_on_space();
    assert(result.handled);
    assert(result.replacement == "Việt Nam ");

    // reset() drops the current word.
    macro.record_char(U'd');
    macro.record_char(U'd');
    macro.reset();
    result = macro.evaluate_on_space();
    assert(!result.handled);

    // reload replaces the table; keys are trimmed + lowercased.
    macro.set_auto_caps(false);
    macro.reload({{"  new ", "value"}});
    macro.record_char(U'N');
    macro.record_char(U'E');
    macro.record_char(U'W');
    result = macro.evaluate_on_space();
    assert(result.handled && result.replacement == "value ");

    return 0;
}
