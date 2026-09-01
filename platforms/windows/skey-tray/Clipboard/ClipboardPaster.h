#pragma once

#include <string>

namespace skey::windows {

// Writes UTF-8 text to the clipboard and synthesizes Ctrl+V into the
// foreground app, mirroring the macOS triggerSystemPaste (50ms settle).
class ClipboardPaster {
public:
    static bool paste_text(const std::string& utf8);
};

} // namespace skey::windows
