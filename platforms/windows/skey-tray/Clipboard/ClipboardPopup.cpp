#include "ClipboardPopup.h"

#include "../../Shared/Clipboard/ClipboardText.h"

#include <algorithm>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace skey::windows {

namespace {

constexpr int kWindowWidth = 480;
constexpr int kWindowHeight = 400;
constexpr int kMargin = 8;
constexpr int kEditHeight = 26;
constexpr std::size_t kPreviewChars = 160;

struct PopupState {
    std::vector<ClipboardPopupItem> items;
    std::vector<std::size_t> visible;
    ClipboardPopup::Choose choose;
    HWND edit = nullptr;
    HWND list = nullptr;
    HWND window = nullptr;
    WNDPROC edit_proc = nullptr;
    bool chosen = false;
};

std::wstring to_wide(const std::string& utf8) {
    if (utf8.empty()) return {};
    const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
    std::wstring out(static_cast<std::size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), out.data(), length);
    return out;
}

std::string to_utf8(const std::wstring& wide) {
    if (wide.empty()) return {};
    const int length = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()), nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<std::size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()), out.data(), length, nullptr, nullptr);
    return out;
}

std::string one_line_preview(const std::string& text) {
    std::string preview;
    preview.reserve(std::min(text.size(), kPreviewChars * 4));
    std::size_t chars = 0;
    std::size_t i = 0;
    while (i < text.size() && chars < kPreviewChars) {
        const unsigned char b = static_cast<unsigned char>(text[i]);
        std::size_t step = 1;
        if (b >= 0xF0) step = 4;
        else if (b >= 0xE0) step = 3;
        else if (b >= 0xC0) step = 2;
        if (i + step > text.size()) break;
        if (text[i] == '\n') preview += " \xE2\x86\xB5 ";  // " ↵ "
        else if (text[i] == '\r' || text[i] == '\t') preview += ' ';
        else preview.append(text, i, step);
        i += step;
        ++chars;
    }
    if (i < text.size()) preview += "...";
    return preview;
}

void refresh_list(PopupState& state) {
    const int length = GetWindowTextLengthW(state.edit);
    std::wstring query_wide(static_cast<std::size_t>(length) + 1, L'\0');
    GetWindowTextW(state.edit, query_wide.data(), length + 1);
    query_wide.resize(static_cast<std::size_t>(length));
    const std::string query = to_utf8(query_wide);

    state.visible.clear();
    if (query.empty()) {
        for (std::size_t i = 0; i < state.items.size(); ++i) state.visible.push_back(i);
    } else {
        struct Scored {
            std::size_t index;
            long long score;
        };
        std::vector<Scored> scored;
        for (std::size_t i = 0; i < state.items.size(); ++i) {
            const auto score = ClipboardText::rank(state.items[i].text, state.items[i].folded, query);
            if (score >= 0) scored.push_back({i, score});
        }
        std::stable_sort(scored.begin(), scored.end(), [](const Scored& a, const Scored& b) {
            return a.score > b.score;
        });
        for (const auto& entry : scored) state.visible.push_back(entry.index);
    }

    SendMessageW(state.list, LB_RESETCONTENT, 0, 0);
    for (const std::size_t index : state.visible) {
        const auto& item = state.items[index];
        std::string label;
        if (item.pinned) label = "\xE2\x98\x85 ";  // "★ "
        label += one_line_preview(item.text);
        SendMessageW(state.list, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(to_wide(label).c_str()));
    }
    if (!state.visible.empty()) {
        SendMessageW(state.list, LB_SETCURSEL, 0, 0);
    }
}

void choose_selected(PopupState& state) {
    const auto selection = static_cast<int>(SendMessageW(state.list, LB_GETCURSEL, 0, 0));
    if (selection == LB_ERR || state.visible.empty()) return;
    const std::size_t slot = static_cast<std::size_t>(selection);
    if (slot >= state.visible.size()) return;
    state.chosen = true;
    if (state.choose) state.choose(state.items[state.visible[slot]].text);
    DestroyWindow(state.window);
}

LRESULT CALLBACK edit_subclass(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto* state = reinterpret_cast<PopupState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (state == nullptr) return DefWindowProcW(hwnd, msg, wparam, lparam);
    switch (msg) {
        case WM_KEYDOWN:
            if (wparam == VK_RETURN) {
                choose_selected(*state);
                return 0;
            }
            if (wparam == VK_ESCAPE) {
                DestroyWindow(state->window);
                return 0;
            }
            if (wparam == VK_DOWN || wparam == VK_UP) {
                const int count = static_cast<int>(SendMessageW(state->list, LB_GETCOUNT, 0, 0));
                if (count > 0) {
                    const int current = static_cast<int>(SendMessageW(state->list, LB_GETCURSEL, 0, 0));
                    int next = wparam == VK_DOWN ? current + 1 : current - 1;
                    if (current == LB_ERR) next = 0;
                    next = std::clamp(next, 0, count - 1);
                    SendMessageW(state->list, LB_SETCURSEL, static_cast<WPARAM>(next), 0);
                }
                return 0;
            }
            if ((GetKeyState(VK_CONTROL) & 0x8000) != 0 && wparam >= '1' && wparam <= '9') {
                const std::size_t slot = wparam - '1';
                if (slot < state->visible.size()) {
                    SendMessageW(state->list, LB_SETCURSEL, slot, 0);
                    choose_selected(*state);
                }
                return 0;
            }
            break;
        case WM_CHAR:
            if (wparam == VK_RETURN || wparam == VK_ESCAPE) return 0;
            break;
        default:
            break;
    }
    return CallWindowProcW(state->edit_proc, hwnd, msg, wparam, lparam);
}

LRESULT CALLBACK popup_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto* state = reinterpret_cast<PopupState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
    case WM_COMMAND:
        if (state != nullptr && LOWORD(lparam) == 2001 && HIWORD(wparam) == EN_CHANGE) {
            refresh_list(*state);
            return 0;
        }
        if (state != nullptr && LOWORD(lparam) == 2002 && HIWORD(wparam) == LBN_DBLCLK) {
            choose_selected(*state);
            return 0;
        }
        break;
    case WM_SIZE: {
        if (state == nullptr) break;
        const int width = LOWORD(lparam);
        const int height = HIWORD(lparam);
        MoveWindow(state->edit, kMargin, kMargin, width - 2 * kMargin, kEditHeight, TRUE);
        MoveWindow(state->list, kMargin, kMargin + kEditHeight + 6, width - 2 * kMargin,
                   height - 2 * kMargin - kEditHeight - 6, TRUE);
        return 0;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

POINT popup_origin() {
    POINT cursor{};
    GetCursorPos(&cursor);
    const HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    RECT work{};
    if (GetMonitorInfoW(monitor, &info) != FALSE) {
        work = info.rcWork;
    } else {
        work = {0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)};
    }
    POINT origin{cursor.x - kWindowWidth / 2, cursor.y - kWindowHeight / 3};
    origin.x = std::clamp<long>(origin.x, work.left, std::max<long>(work.left, work.right - kWindowWidth));
    origin.y = std::clamp<long>(origin.y, work.top, std::max<long>(work.top, work.bottom - kWindowHeight));
    return origin;
}

} // namespace

bool ClipboardPopup::show(std::vector<ClipboardPopupItem> items, Choose choose) {
    static const ATOM atom = [] {
        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = popup_proc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        wc.lpszClassName = L"SKeyClipboardPopup";
        return RegisterClassExW(&wc);
    }();
    if (atom == 0) return false;

    PopupState state;
    state.items = std::move(items);
    state.choose = std::move(choose);

    const POINT origin = popup_origin();
    const HWND window = CreateWindowExW(
        WS_EX_TOPMOST, reinterpret_cast<LPCWSTR>(static_cast<std::uintptr_t>(atom)),
        L"SKey Clipboard", WS_POPUP | WS_BORDER | WS_SYSMENU, origin.x, origin.y,
        kWindowWidth, kWindowHeight, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (window == nullptr) return false;
    state.window = window;
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&state));

    const int width = kWindowWidth - 2 * kMargin;
    state.edit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
                                 WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
                                 kMargin, kMargin, width, kEditHeight, window,
                                 reinterpret_cast<HMENU>(static_cast<std::uintptr_t>(2001)),
                                 GetModuleHandleW(nullptr), nullptr);
    state.list = CreateWindowExW(WS_EX_CLIENTEDGE, L"LISTBOX", L"",
                                 WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY,
                                 kMargin, kMargin + kEditHeight + 6, width,
                                 kWindowHeight - 2 * kMargin - kEditHeight - 6, window,
                                 reinterpret_cast<HMENU>(static_cast<std::uintptr_t>(2002)),
                                 GetModuleHandleW(nullptr), nullptr);

    state.edit_proc = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(state.edit, GWLP_WNDPROC,
                                                                  reinterpret_cast<LONG_PTR>(edit_subclass)));
    SetWindowLongPtrW(state.edit, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&state));

    refresh_list(state);
    SetFocus(state.edit);
    ShowWindow(window, SW_SHOWNOACTIVATE);
    SetForegroundWindow(window);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        if (IsDialogMessageW(window, &msg) == FALSE) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
    return state.chosen;
}

} // namespace skey::windows

#else // Non-Windows: no popup.

namespace skey::windows {

bool ClipboardPopup::show(std::vector<ClipboardPopupItem>, Choose) { return false; }

} // namespace skey::windows

#endif
