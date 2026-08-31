#include "TranslationHud.h"

#include "../../Shared/Localization/LocalizationService.h"

#include <algorithm>
#include <cstdint>
#include <iterator>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace skey::windows {

namespace {

constexpr int kWindowWidth = 440;
constexpr int kWindowHeight = 300;
constexpr int kMargin = 8;
constexpr int kInputHeight = 26;
constexpr int kRowHeight = 26;
constexpr int kStatusHeight = 18;
constexpr UINT_PTR kIdInput = 3001;
constexpr UINT_PTR kIdCombo = 3002;
constexpr UINT_PTR kIdTranslate = 3003;
constexpr UINT_PTR kIdResult = 3004;
constexpr UINT_PTR kIdStatus = 3005;
constexpr UINT kMsgResultReady = WM_APP + 1;

struct LanguageChoice {
    const wchar_t* code;
    const wchar_t* label;
};

constexpr LanguageChoice kLanguages[] = {
    {L"vi", L"Ti\x1EBFng Vi\x1EC7t"},
    {L"en", L"English"},
    {L"ja", L"\x65E5\x672C\x8A9E"},
    {L"ko", L"\xD55C\xAD6D\xC5B4"},
    {L"zh-CN", L"\x4E2D\x6587"},
    {L"fr", L"Fran\xE7" "ais"},
    {L"de", L"Deutsch"},
    {L"ru", L"\x420\x443\x441\x441\x43A\x438\x439"},
    {L"es", L"Espa\xF1ol"},
    {L"th", L"\xE44\xE17\xE22"},
    {L"km", L"\x1781\x17D2\x1798\x17C2\x179A"},
    {L"lo", L"\xE81\xE88\xEA5\xEB2"},
};

// Heap-owned so a translation finishing after the HUD closed cannot touch
// freed stack state; the window only reads it while its modal loop runs.
struct TranslationCore {
    TranslatorService service;
    std::mutex mutex;
    TranslateOutcome pending;
    bool busy = false;
};

struct HudState {
    TranslationHudConfig config;
    std::shared_ptr<TranslationCore> core;
    std::vector<std::wstring> codes;
    HWND window = nullptr;
    HWND input = nullptr;
    HWND combo = nullptr;
    HWND button = nullptr;
    HWND result = nullptr;
    HWND status = nullptr;
    WNDPROC input_proc = nullptr;
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

std::string window_text(HWND hwnd) {
    const int length = GetWindowTextLengthW(hwnd);
    std::wstring wide(static_cast<std::size_t>(length) + 1, L'\0');
    GetWindowTextW(hwnd, wide.data(), length + 1);
    wide.resize(static_cast<std::size_t>(length));
    return to_utf8(wide);
}

std::string selected_target(const HudState& state) {
    const auto selection = static_cast<int>(SendMessageW(state.combo, CB_GETCURSEL, 0, 0));
    if (selection == CB_ERR) return state.config.target_language;
    const std::size_t index = static_cast<std::size_t>(selection);
    if (index >= state.codes.size()) return state.config.target_language;
    return to_utf8(state.codes[index]);
}

void start_translation(HudState& state) {
    {
        std::lock_guard<std::mutex> lock(state.core->mutex);
        if (state.core->busy) return;
        state.core->busy = true;
    }
    const std::string text = window_text(state.input);
    if (text.empty()) {
        std::lock_guard<std::mutex> lock(state.core->mutex);
        state.core->busy = false;
        return;
    }
    TranslateParams params;
    params.text = text;
    params.source = state.config.auto_detect ? "auto" : "en";
    params.target = selected_target(state);

    EnableWindow(state.button, FALSE);
    SetWindowTextW(state.status,
                   to_wide(std::string{LocalizationService::shared().text("hud.translate.busy")}).c_str());

    const HWND window = state.window;
    std::shared_ptr<TranslationCore> core = state.core;
    std::vector<TranslatorEngine> engines = state.config.engines;
    std::thread([window, core = std::move(core), params = std::move(params),
                 engines = std::move(engines)] {
        const TranslateOutcome outcome = core->service.translate(params, engines);
        {
            std::lock_guard<std::mutex> lock(core->mutex);
            core->pending = outcome;
        }
        PostMessageW(window, kMsgResultReady, 0, 0);
    }).detach();
}

void apply_result(HudState& state) {
    TranslateOutcome outcome;
    {
        std::lock_guard<std::mutex> lock(state.core->mutex);
        outcome = std::move(state.core->pending);
        state.core->pending = {};
        state.core->busy = false;
    }
    EnableWindow(state.button, TRUE);
    if (outcome.ok) {
        SetWindowTextW(state.result, to_wide(outcome.text).c_str());
        const std::wstring line = to_wide(outcome.engine) + L" \xB7 " +
                                  std::to_wstring(outcome.latency_ms) + L" ms";
        SetWindowTextW(state.status, line.c_str());
    } else {
        SetWindowTextW(state.result, L"");
        const std::string error = outcome.error.empty()
                                      ? std::string{LocalizationService::shared().text("hud.translate.failed")}
                                      : outcome.error;
        SetWindowTextW(state.status, to_wide(error).c_str());
    }
}

LRESULT CALLBACK input_subclass(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto* state = reinterpret_cast<HudState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (state == nullptr) return DefWindowProcW(hwnd, msg, wparam, lparam);
    if (msg == WM_KEYDOWN) {
        if (wparam == VK_RETURN) {
            start_translation(*state);
            return 0;
        }
        if (wparam == VK_ESCAPE) {
            DestroyWindow(state->window);
            return 0;
        }
    }
    return CallWindowProcW(state->input_proc, hwnd, msg, wparam, lparam);
}

LRESULT CALLBACK hud_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto* state = reinterpret_cast<HudState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
    case WM_COMMAND:
        if (state != nullptr && LOWORD(lparam) == kIdTranslate && HIWORD(wparam) == BN_CLICKED) {
            start_translation(*state);
            return 0;
        }
        break;
    case kMsgResultReady:
        if (state != nullptr) apply_result(*state);
        return 0;
    case WM_SIZE: {
        if (state == nullptr) break;
        const int width = LOWORD(lparam);
        const int height = HIWORD(lparam);
        MoveWindow(state->input, kMargin, kMargin, width - 2 * kMargin, kInputHeight, TRUE);
        const int row_y = kMargin + kInputHeight + 6;
        MoveWindow(state->combo, kMargin, row_y, 160, 200, TRUE);
        MoveWindow(state->button, kMargin + 168, row_y, 100, kRowHeight, TRUE);
        const int result_y = row_y + kRowHeight + 6;
        MoveWindow(state->result, kMargin, result_y, width - 2 * kMargin,
                   height - result_y - kStatusHeight - 6 - kMargin, TRUE);
        MoveWindow(state->status, kMargin, height - kStatusHeight - kMargin,
                   width - 2 * kMargin, kStatusHeight, TRUE);
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

POINT hud_origin() {
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

void TranslationHud::show(TranslationHudConfig config, TranslatorService::HttpFn http) {
    static const ATOM atom = [] {
        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = hud_proc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        wc.lpszClassName = L"SKeyTranslationHud";
        return RegisterClassExW(&wc);
    }();
    if (atom == 0) return;

    HudState state;
    state.config = std::move(config);
    state.core = std::make_shared<TranslationCore>();
    state.core->service.set_http(std::move(http));

    const POINT origin = hud_origin();
    const HWND window = CreateWindowExW(
        WS_EX_TOPMOST, reinterpret_cast<LPCWSTR>(static_cast<std::uintptr_t>(atom)),
        to_wide(std::string{LocalizationService::shared().text("hud.translate.title")}).c_str(),
        WS_POPUP | WS_BORDER | WS_SYSMENU, origin.x, origin.y,
        kWindowWidth, kWindowHeight, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (window == nullptr) return;
    state.window = window;
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&state));

    const int width = kWindowWidth - 2 * kMargin;
    state.input = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
                                  WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
                                  kMargin, kMargin, width, kInputHeight, window,
                                  reinterpret_cast<HMENU>(kIdInput),
                                  GetModuleHandleW(nullptr), nullptr);
    const int row_y = kMargin + kInputHeight + 6;
    state.combo = CreateWindowExW(0, L"COMBOBOX", L"",
                                  WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_TABSTOP,
                                  kMargin, row_y, 160, 200, window,
                                  reinterpret_cast<HMENU>(kIdCombo),
                                  GetModuleHandleW(nullptr), nullptr);
    state.button = CreateWindowExW(0, L"BUTTON",
                                   to_wide(std::string{LocalizationService::shared().text("hud.translate.button")}).c_str(),
                                   WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                                   kMargin + 168, row_y, 100, kRowHeight, window,
                                   reinterpret_cast<HMENU>(kIdTranslate),
                                   GetModuleHandleW(nullptr), nullptr);
    const int result_y = row_y + kRowHeight + 6;
    state.result = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
                                   WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_READONLY |
                                       WS_VSCROLL | ES_AUTOVSCROLL,
                                   kMargin, result_y, width,
                                   kWindowHeight - result_y - kStatusHeight - 6 - kMargin, window,
                                   reinterpret_cast<HMENU>(kIdResult),
                                   GetModuleHandleW(nullptr), nullptr);
    state.status = CreateWindowExW(0, L"STATIC", L"", WS_CHILD | WS_VISIBLE,
                                   kMargin, kWindowHeight - kStatusHeight - kMargin,
                                   width, kStatusHeight, window,
                                   reinterpret_cast<HMENU>(kIdStatus),
                                   GetModuleHandleW(nullptr), nullptr);

    int selected = 0;
    const std::wstring configured = to_wide(state.config.target_language);
    bool found = false;
    for (std::size_t i = 0; i < std::size(kLanguages); ++i) {
        SendMessageW(state.combo, CB_ADDSTRING, 0,
                     reinterpret_cast<LPARAM>(kLanguages[i].label));
        state.codes.emplace_back(kLanguages[i].code);
        if (configured == kLanguages[i].code) {
            selected = static_cast<int>(i);
            found = true;
        }
    }
    if (!found) {
        SendMessageW(state.combo, CB_ADDSTRING, 0,
                     reinterpret_cast<LPARAM>(configured.c_str()));
        state.codes.push_back(configured);
        selected = static_cast<int>(state.codes.size()) - 1;
    }
    SendMessageW(state.combo, CB_SETCURSEL, static_cast<WPARAM>(selected), 0);

    state.input_proc = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(
        state.input, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(input_subclass)));
    SetWindowLongPtrW(state.input, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&state));

    SetFocus(state.input);
    ShowWindow(window, SW_SHOWNOACTIVATE);
    SetForegroundWindow(window);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        if (IsDialogMessageW(window, &msg) == FALSE) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
}

} // namespace skey::windows

#else // Non-Windows: no HUD.

namespace skey::windows {

void TranslationHud::show(TranslationHudConfig, TranslatorService::HttpFn) {}

} // namespace skey::windows

#endif
