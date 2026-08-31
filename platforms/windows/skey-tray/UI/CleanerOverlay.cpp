#include "CleanerOverlay.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <utility>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace skey::windows {

namespace {

constexpr int kWindowWidth = 540;
constexpr int kWindowHeight = 60;
constexpr UINT_PTR kTimerId = 4001;
constexpr UINT_PTR kTimerIntervalMs = 50;
constexpr double kPi = 3.14159265358979323846;
constexpr std::uint64_t kHoldMs = 2000;

struct OverlayState {
    std::shared_ptr<CleanerOverlayBridge> bridge;
    HWND window = nullptr;
    bool holding = false;
    std::uint64_t down_ms = 0;
};

std::uint64_t steady_now_ms() {
    return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch())
            .count());
}

double hold_progress(const OverlayState& state) {
    if (!state.holding) return 0.0;
    const std::uint64_t now = steady_now_ms();
    if (now <= state.down_ms) return 0.0;
    return std::min(1.0, static_cast<double>(now - state.down_ms) / static_cast<double>(kHoldMs));
}

void draw_progress_ring(HDC dc, int cx, int cy, int radius, double progress) {
    SelectObject(dc, GetStockObject(NULL_BRUSH));
    HPEN track = CreatePen(PS_SOLID, 3, RGB(150, 150, 150));
    HPEN old = static_cast<HPEN>(SelectObject(dc, track));
    Ellipse(dc, cx - radius, cy - radius, cx + radius, cy + radius);
    DeleteObject(SelectObject(dc, old));

    if (progress > 0.0) {
        HPEN bar = CreatePen(PS_SOLID, 3, RGB(46, 204, 113));
        old = static_cast<HPEN>(SelectObject(dc, bar));
        POINT points[65];
        const double sweep = progress * 2.0 * kPi;
        const int steps = std::max(2, static_cast<int>(64.0 * progress));
        int count = 0;
        for (int i = 0; i <= steps && count < 65; ++i) {
            const double angle = -kPi / 2.0 + sweep * i / steps;
            points[count].x = cx + static_cast<LONG>(radius * std::cos(angle));
            points[count].y = cy + static_cast<LONG>(radius * std::sin(angle));
            ++count;
        }
        Polyline(dc, points, count);
        DeleteObject(SelectObject(dc, old));
    }
}

void paint(OverlayState& state, HDC dc) {
    RECT client{};
    GetClientRect(state.window, &client);

    // Capsule background.
    HBRUSH background = CreateSolidBrush(RGB(38, 38, 38));
    HPEN border = CreatePen(PS_SOLID, 1, RGB(90, 90, 90));
    HPEN old_pen = static_cast<HPEN>(SelectObject(dc, border));
    HBRUSH old_brush = static_cast<HBRUSH>(SelectObject(dc, background));
    RoundRect(dc, client.left, client.top, client.right, client.bottom,
              kWindowHeight, kWindowHeight);
    SelectObject(dc, old_pen);
    SelectObject(dc, old_brush);
    DeleteObject(border);
    DeleteObject(background);

    SetBkMode(dc, TRANSPARENT);

    // Locked badge.
    RECT badge{16, 14, 112, 46};
    HBRUSH orange = CreateSolidBrush(RGB(230, 126, 34));
    FillRect(dc, &badge, orange);
    DeleteObject(orange);
    SetTextColor(dc, RGB(255, 255, 255));
    HFONT bold = CreateFontW(16, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                             OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
    HFONT old_font = static_cast<HFONT>(SelectObject(dc, bold));
    DrawTextW(dc, L"Locked", -1, &badge, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

    // Esc ring + label.
    const double progress = hold_progress(state);
    draw_progress_ring(dc, 150, 30, 15, progress);
    SetTextColor(dc, state.holding ? RGB(46, 204, 113) : RGB(220, 220, 220));
    HFONT small = CreateFontW(11, 0, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                              OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH, L"Segoe UI");
    SelectObject(dc, small);
    RECT esc_label{132, 22, 168, 38};
    DrawTextW(dc, L"Esc", -1, &esc_label, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    DeleteObject(SelectObject(dc, bold));
    DeleteObject(small);

    // Hint text.
    SetTextColor(dc, state.holding ? RGB(46, 204, 113) : RGB(220, 220, 220));
    HFONT hint = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                             OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
    old_font = static_cast<HFONT>(SelectObject(dc, hint));
    RECT text{180, 0, client.right - 16, kWindowHeight};
    DrawTextW(dc, state.holding ? L"Keep holding Esc\u2026"
                                : L"Hold Esc for 2 seconds to unlock \u2014 click to unlock",
              -1, &text, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
    DeleteObject(SelectObject(dc, old_font));
}

LRESULT CALLBACK overlay_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto* state = reinterpret_cast<OverlayState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
    case WM_PAINT: {
        if (state == nullptr) break;
        PAINTSTRUCT ps{};
        HDC dc = BeginPaint(hwnd, &ps);
        paint(*state, dc);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_TIMER:
        if (state != nullptr && wparam == kTimerId) {
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        }
        break;
    case kCleanerEventMessage:
        if (state == nullptr) return 0;
        switch (wparam) {
        case kCleanerEscDown:
            state->holding = true;
            state->down_ms = static_cast<std::uint64_t>(lparam);
            SetTimer(hwnd, kTimerId, kTimerIntervalMs, nullptr);
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case kCleanerEscUp:
        case kCleanerOtherKey:
            state->holding = false;
            KillTimer(hwnd, kTimerId);
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case kCleanerDeactivated:
            DestroyWindow(hwnd);
            return 0;
        default:
            return 0;
        }
    case WM_LBUTTONDOWN: {
        if (state == nullptr) break;
        std::function<void()> unlock;
        {
            std::lock_guard<std::mutex> lock(state->bridge->mutex);
            unlock = state->bridge->unlock_request;
        }
        if (unlock) unlock();  // pipeline emits deactivated, which closes us
        return 0;
    }
    case WM_DESTROY:
        KillTimer(hwnd, kTimerId);
        PostQuitMessage(0);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

POINT overlay_origin() {
    RECT work{0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)};
    const HMONITOR monitor = MonitorFromPoint({work.right / 2, work.bottom / 2},
                                              MONITOR_DEFAULTTOPRIMARY);
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(monitor, &info) != FALSE) work = info.rcWork;
    return {(work.left + work.right - kWindowWidth) / 2,
            (work.top + work.bottom - kWindowHeight) / 2};
}

} // namespace

void CleanerOverlay::run(std::shared_ptr<CleanerOverlayBridge> bridge) {
    if (!bridge) return;
    static const ATOM atom = [] {
        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = overlay_proc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.lpszClassName = L"SKeyCleanerOverlay";
        return RegisterClassExW(&wc);
    }();
    if (atom == 0) return;

    OverlayState state;
    state.bridge = std::move(bridge);

    const POINT origin = overlay_origin();
    const HWND window = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW,
        reinterpret_cast<LPCWSTR>(static_cast<std::uintptr_t>(atom)), L"SKey Cleaner",
        WS_POPUP, origin.x, origin.y, kWindowWidth, kWindowHeight, nullptr, nullptr,
        GetModuleHandleW(nullptr), nullptr);
    if (window == nullptr) return;
    state.window = window;
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&state));
    {
        std::lock_guard<std::mutex> lock(state.bridge->mutex);
        state.bridge->window = window;
    }
    ShowWindow(window, SW_SHOWNOACTIVATE);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    std::lock_guard<std::mutex> lock(state.bridge->mutex);
    state.bridge->window = nullptr;
}

} // namespace skey::windows

#else // Non-Windows: no overlay.

namespace skey::windows {

void CleanerOverlay::run(std::shared_ptr<CleanerOverlayBridge>) {}

} // namespace skey::windows

#endif
