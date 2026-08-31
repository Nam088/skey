#include "LaunchAtLogin.h"

#include <string>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

#ifdef _WIN32

namespace {

constexpr wchar_t kRunKeyPath[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"SKey";

std::wstring current_exe_command() {
    wchar_t buffer[MAX_PATH]{};
    const DWORD len = GetModuleFileNameW(nullptr, buffer, MAX_PATH);
    if (len == 0) return {};
    return L"\"" + std::wstring(buffer, len) + L"\"";
}

bool read_value(std::wstring& out) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKeyPath, 0, KEY_READ, &key) != ERROR_SUCCESS) {
        return false;
    }
    wchar_t buffer[1024]{};
    DWORD bytes = sizeof(buffer);
    const LONG status = RegQueryValueExW(key, kValueName, nullptr, nullptr,
                                         reinterpret_cast<BYTE*>(buffer), &bytes);
    RegCloseKey(key);
    if (status != ERROR_SUCCESS) return false;
    out.assign(buffer, bytes / sizeof(wchar_t));
    while (!out.empty() && out.back() == L'\0') out.pop_back();
    return true;
}

} // namespace

bool LaunchAtLogin::enabled() {
    std::wstring value;
    return read_value(value);
}

bool LaunchAtLogin::set_enabled(bool enabled) {
    std::wstring existing;
    const bool present = read_value(existing);
    if (present == enabled) return true;

    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKeyPath, 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
        return false;
    }
    LONG status = ERROR_SUCCESS;
    if (enabled) {
        const std::wstring command = current_exe_command();
        if (command.empty()) {
            RegCloseKey(key);
            return false;
        }
        status = RegSetValueExW(key, kValueName, 0, REG_SZ,
                                reinterpret_cast<const BYTE*>(command.c_str()),
                                static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    } else {
        status = RegDeleteValueW(key, kValueName);
        if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
    }
    RegCloseKey(key);
    return status == ERROR_SUCCESS;
}

#else

bool LaunchAtLogin::enabled() { return false; }
bool LaunchAtLogin::set_enabled(bool) { return false; }

#endif

} // namespace skey::windows
