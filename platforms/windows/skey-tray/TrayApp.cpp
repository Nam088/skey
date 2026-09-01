#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>

#include "../Shared/Localization/LocalizationService.h"
#include "../Shared/Logging/AppLogger.h"
#include "TrayIpcHandler.h"
#include "TrayRuntime.h"

#include <string>

namespace {

constexpr UINT WM_TRAYICON = WM_APP + 1;
constexpr UINT ID_TRAYICON = 1;
constexpr WORD IDM_TOGGLE = 1001;
constexpr WORD IDM_SETTINGS = 1002;
constexpr WORD IDM_EXIT = 1003;

HWND g_hwnd = nullptr;
NOTIFYICONDATAW g_nid{};
skey::windows::TrayRuntime* g_runtime = nullptr;
std::wstring g_update_url;

std::wstring to_wide(const std::string& utf8) {
    if (utf8.empty()) return {};
    const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
    std::wstring out(static_cast<std::size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), out.data(), length);
    return out;
}

void show_update_notification(const skey::windows::UpdateInfo& info) {
    auto& loc = skey::windows::LocalizationService::shared();
    g_update_url = to_wide(!info.asset_url.empty() ? info.asset_url : info.release_url);
    g_nid.uFlags |= NIF_INFO;
    g_nid.dwInfoFlags = NIIF_INFO | NIIF_LARGE_ICON;
    const std::wstring title = to_wide(std::string{loc.text("tray.update.title")});
    wcsncpy_s(g_nid.szInfoTitle, title.c_str(), std::size(g_nid.szInfoTitle) - 1);
    const std::wstring message =
        to_wide(std::string{loc.text("tray.update.message_prefix")}) + to_wide(info.version) +
        to_wide(std::string{loc.text("tray.update.message_suffix")});
    wcsncpy_s(g_nid.szInfo, message.c_str(), std::size(g_nid.szInfo) - 1);
    Shell_NotifyIconW(NIM_MODIFY, &g_nid);
    g_nid.uFlags &= ~static_cast<decltype(g_nid.uFlags)>(NIF_INFO);
}

HICON create_status_icon(bool vietnamese) {
    constexpr int size = 16;
    HDC screen = GetDC(nullptr);
    HDC dc = CreateCompatibleDC(screen);
    HBITMAP color = CreateCompatibleBitmap(screen, size, size);
    HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);

    SelectObject(dc, color);
    RECT rc{0, 0, size, size};
    HBRUSH bg = CreateSolidBrush(vietnamese ? RGB(0, 120, 215) : RGB(128, 128, 128));
    FillRect(dc, &rc, bg);
    DeleteObject(bg);

    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, RGB(255, 255, 255));
    HFONT font = CreateFontW(size - 2, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
    HFONT old_font = static_cast<HFONT>(SelectObject(dc, font));
    const wchar_t letter = vietnamese ? L'V' : L'E';
    DrawTextW(dc, &letter, 1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    SelectObject(dc, old_font);
    DeleteObject(font);
    ReleaseDC(nullptr, screen);
    DeleteDC(dc);

    ICONINFO info{};
    info.fIcon = TRUE;
    info.xHotspot = 0;
    info.yHotspot = 0;
    info.hbmMask = mask;
    info.hbmColor = color;
    HICON icon = CreateIconIndirect(&info);
    DeleteObject(color);
    DeleteObject(mask);
    return icon;
}

void update_tray_icon(bool vietnamese) {
    static HICON current_icon = nullptr;
    if (current_icon != nullptr) DestroyIcon(current_icon);
    current_icon = create_status_icon(vietnamese);
    g_nid.hIcon = current_icon;

    const std::wstring tip = vietnamese ? L"SKey - Ti\u1EBFng Vi\u1EC7t" : L"SKey - English";
    wcsncpy_s(g_nid.szTip, tip.c_str(), std::size(g_nid.szTip) - 1);
    g_nid.szTip[std::size(g_nid.szTip) - 1] = L'\0';
    Shell_NotifyIconW(NIM_MODIFY, &g_nid);
}

void show_context_menu() {
    POINT pt{};
    GetCursorPos(&pt);
    auto& loc = skey::windows::LocalizationService::shared();
    const auto item = [&loc](const char* key) {
        return to_wide(std::string{loc.text(key)});
    };
    HMENU menu = CreatePopupMenu();
    const bool is_vn = g_runtime != nullptr && g_runtime->vietnamese_enabled();
    AppendMenuW(menu, MF_STRING, IDM_TOGGLE,
                item(is_vn ? "tray.menu.switch_english" : "tray.menu.switch_vietnamese").c_str());
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, IDM_SETTINGS, item("tray.menu.settings").c_str());
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, IDM_EXIT, item("tray.menu.quit").c_str());

    SetForegroundWindow(g_hwnd);
    TrackPopupMenu(menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, g_hwnd, nullptr);
    PostMessageW(g_hwnd, WM_NULL, 0, 0);
    DestroyMenu(menu);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_TRAYICON:
        switch (LOWORD(lp)) {
        case NIN_BALLOONUSERCLICK:
            if (!g_update_url.empty()) {
                ShellExecuteW(nullptr, L"open", g_update_url.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
            }
            break;
        case WM_LBUTTONUP:
            if (g_runtime != nullptr) {
                g_runtime->toggle_language();
                update_tray_icon(g_runtime->vietnamese_enabled());
            }
            break;
        case WM_RBUTTONUP:
            show_context_menu();
            break;
        }
        return 0;
    case WM_COMMAND:
        switch (LOWORD(wp)) {
        case IDM_TOGGLE:
            if (g_runtime != nullptr) {
                g_runtime->toggle_language();
                update_tray_icon(g_runtime->vietnamese_enabled());
            }
            break;
        case IDM_SETTINGS:
            ShellExecuteW(nullptr, L"open", L"skey-settings.exe", nullptr, nullptr, SW_SHOW);
            break;
        case IDM_EXIT:
            Shell_NotifyIconW(NIM_DELETE, &g_nid);
            PostQuitMessage(0);
            break;
        }
        return 0;
    case WM_DESTROY:
        Shell_NotifyIconW(NIM_DELETE, &g_nid);
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    using namespace skey::windows;

    AppLogger::instance().initialize("skey-tray");
    SKEY_LOG_INFO("==================================================");
    SKEY_LOG_INFO("skey-tray process started.");

    WNDCLASSW wc{};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = instance;
    wc.lpszClassName = L"SKeyTrayClass";
    RegisterClassW(&wc);

    g_hwnd = CreateWindowExW(0, wc.lpszClassName, L"SKey Tray", 0, 0, 0, 0, 0,
                              HWND_MESSAGE, nullptr, instance, nullptr);
    if (g_hwnd == nullptr) return 1;

    TrayRuntime runtime([](bool vietnamese) { update_tray_icon(vietnamese); },
                        [](const UpdateInfo& info) { show_update_notification(info); });
    TrayIpcHandler handler(runtime);
    g_runtime = &runtime;

    if (!runtime.start_ipc(handler)) return 1;

    g_nid = {};
    g_nid.cbSize = sizeof(g_nid);
    g_nid.hWnd = g_hwnd;
    g_nid.uID = ID_TRAYICON;
    g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;
    g_nid.hIcon = create_status_icon(runtime.vietnamese_enabled());
    const std::wstring tip = runtime.vietnamese_enabled() ? L"SKey - Ti\u1EBFng Vi\u1EC7t" : L"SKey - English";
    wcsncpy_s(g_nid.szTip, tip.c_str(), std::size(g_nid.szTip) - 1);
    g_nid.szTip[std::size(g_nid.szTip) - 1] = L'\0';
    Shell_NotifyIconW(NIM_ADD, &g_nid);

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    runtime.stop();
    g_runtime = nullptr;
    return 0;
}

#endif
