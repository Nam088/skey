#include "ForegroundAppTracker.h"

#include <algorithm>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

namespace {

std::string lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

} // namespace

std::string ForegroundAppTracker::normalize(std::string name) {
    // Keep the file name only, lowercase, drop the ".exe" suffix.
    const auto slash = name.find_last_of("/\\");
    if (slash != std::string::npos) name = name.substr(slash + 1);
    name = lower(std::move(name));
    if (name.size() > 4 && name.compare(name.size() - 4, 4, ".exe") == 0) {
        name.erase(name.size() - 4);
    }
    return name;
}

bool ForegroundAppTracker::is_excluded(const std::string& exe_name,
                                       const std::vector<std::string>& excluded_apps) {
    if (excluded_apps.empty()) return false;
    const std::string target = normalize(exe_name);
    if (target.empty()) return false;
    for (const auto& entry : excluded_apps) {
        if (!entry.empty() && normalize(entry) == target) return true;
    }
    return false;
}

bool ForegroundAppTracker::is_developer_tool(const std::string& exe_name) {
    const std::string exe = normalize(exe_name);
    if (exe.empty()) return false;

    // Exact matches: editors, IDEs and terminals.
    static const char* const exact[] = {
        "code", "code - insiders", "code-insiders", "vscode",
        "devenv", "androidstudio", "androidstudio64", "zed", "subl",
        "windowsterminal", "wt", "cmd", "powershell", "pwsh",
        "conemu", "conemu64", "conemuc64",
        "mintty", "hyper", "warp", "wezterm-gui", "alacritty",
        "emeditor", "notepad++", "notepad2", "notepad3",
    };
    for (const char* name : exact) {
        if (exe == name) return true;
    }

    // JetBrains launchers ship as idea64.exe, pycharm64.exe, ...
    static const char* const prefixes[] = {
        "idea", "pycharm", "webstorm", "clion", "rider", "goland",
        "phpstorm", "rubymine", "datagrip", "aqua", "rustrover", "fleet",
    };
    for (const char* prefix : prefixes) {
        if (exe.compare(0, std::char_traits<char>::length(prefix), prefix) == 0) {
            return true;
        }
    }

    return false;
}

#ifdef _WIN32

std::string ForegroundAppTracker::current_exe() {
    const HWND hwnd = GetForegroundWindow();
    if (hwnd == cached_hwnd_ && !cached_exe_.empty()) return cached_exe_;

    std::string exe;
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid != 0) {
        HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (process != nullptr) {
            wchar_t buffer[512]{};
            DWORD size = static_cast<DWORD>(std::size(buffer));
            if (QueryFullProcessImageNameW(process, 0, buffer, &size)) {
                wchar_t* last_slash = buffer;
                for (wchar_t* p = buffer; *p != L'\0'; ++p) {
                    if (*p == L'\\' || *p == L'/') last_slash = p + 1;
                }
                char narrow[512]{};
                int written = WideCharToMultiByte(CP_UTF8, 0, last_slash, -1, narrow,
                                                  sizeof(narrow), nullptr, nullptr);
                if (written > 0) exe.assign(narrow, static_cast<std::size_t>(written - 1));
            }
            CloseHandle(process);
        }
    }

    cached_hwnd_ = hwnd;
    cached_exe_ = std::move(exe);
    return cached_exe_;
}

#endif

} // namespace skey::windows
