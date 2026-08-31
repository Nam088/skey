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
    static std::string normalize(std::string name);

#ifdef _WIN32
    // Exe name of the current foreground process, cached per HWND so the
    // hook thread pays for QueryFullProcessImageName only on window changes.
    std::string current_exe();

private:
    void* cached_hwnd_ = nullptr;
    std::string cached_exe_;
#endif
};

} // namespace skey::windows
