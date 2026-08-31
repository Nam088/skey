#pragma once

#include <string>
#include <vector>

namespace skey::windows {

// Foreground process classification for the excluded-apps bypass (pipeline
// stage 8) and Smart App Switch (auto English in developer tools), mirroring
// macOS AppFocusObserver.category(for:) == .developerTool.
class ForegroundAppTracker {
public:
    // Case-insensitive; a trailing ".exe" on either side is ignored.
    static bool is_excluded(const std::string& exe_name,
                            const std::vector<std::string>& excluded_apps);
    static bool is_developer_tool(const std::string& exe_name);
    // Browsers get the TSF bridge (Phase 5) because their address bars
    // mishandle SendInput backspace+re-inject sequences.
    static bool is_browser(const std::string& exe_name);
    static std::string normalize(std::string name);

#ifdef _WIN32
    // Exe name of the current foreground process, cached per HWND so the
    // hook thread pays for QueryFullProcessImageName only on window changes.
    // out_pid receives the owning process id when provided.
    std::string current_exe(unsigned long* out_pid = nullptr);

private:
    void* cached_hwnd_ = nullptr;
    std::string cached_exe_;
    unsigned long cached_pid_ = 0;
#endif
};

} // namespace skey::windows
