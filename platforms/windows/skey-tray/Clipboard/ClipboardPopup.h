#pragma once

#include <functional>
#include <string>
#include <vector>

namespace skey::windows {

struct ClipboardPopupItem {
    std::string text;   // UTF-8
    std::string folded; // ClipboardText::fold(text)
    bool pinned = false;
};

// Modal clipboard-history popup (search box + ranked list). Blocks until the
// user picks an item (Enter / 1-9 / double-click) or cancels (Esc). Must run
// on a thread that owns no other message loop — TrayRuntime spawns one.
class ClipboardPopup {
public:
    using Choose = std::function<void(std::string text)>;

    static bool show(std::vector<ClipboardPopupItem> items, Choose choose);
};

} // namespace skey::windows
