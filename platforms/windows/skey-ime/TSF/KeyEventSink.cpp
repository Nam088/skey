#ifdef _WIN32
#include "KeyEventSink.h"
#include "KeyEventClassifier.h"

#include <new>

namespace skey::windows {

HRESULT STDMETHODCALLTYPE KeyEventSink::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (riid == IID_IUnknown || riid == IID_ITfKeyEventSink) {
        *object = static_cast<ITfKeyEventSink*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE KeyEventSink::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&references_));
}

ULONG STDMETHODCALLTYPE KeyEventSink::Release() {
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&references_));
    if (count == 0) delete this;
    return count;
}

namespace {

KeyEvent make_event(WPARAM key, LPARAM lparam) noexcept {
    KeyEvent event{};
    event.key_code = static_cast<std::uint32_t>(key);
    event.repeat = (lparam & 0x40000000) != 0;
    event.kind = classify_event_kind(static_cast<std::uint32_t>(key));

    const bool shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
    const bool ctrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    const bool alt = (GetKeyState(VK_MENU) & 0x8000) != 0;
    const bool caps = (GetKeyState(VK_CAPITAL) & 0x0001) != 0;

    event.modifiers = pack_modifiers(shift, ctrl, alt, caps);

    if (ctrl || alt) {
        event.codepoint = static_cast<std::uint32_t>(key);
        return event;
    }

    const UINT scancode = static_cast<UINT>((lparam >> 16) & 0xFF);
    BYTE keyboard_state[256]{};
    GetKeyboardState(keyboard_state);

    WCHAR buffer[8] = {};
    const int result = ToUnicode(static_cast<UINT>(key), scancode, keyboard_state,
                                  buffer, static_cast<int>(std::size(buffer)), 0);

    if (result == 1) {
        event.codepoint = static_cast<std::uint32_t>(buffer[0]);
    } else {
        event.codepoint = key >= 'A' && key <= 'Z'
            ? static_cast<std::uint32_t>(key + ('a' - 'A'))
            : static_cast<std::uint32_t>(key);
    }

    return event;
}

} // namespace

HRESULT STDMETHODCALLTYPE KeyEventSink::OnSetFocus(BOOL foreground) {
    if (!foreground && handler_ != nullptr) handler_->focus_changed();
    return S_OK;
}

HRESULT STDMETHODCALLTYPE KeyEventSink::OnTestKeyDown(ITfContext*, WPARAM key, LPARAM lparam, BOOL* eaten) {
    if (!eaten) return E_POINTER;
    *eaten = handler_ != nullptr && handler_->test(make_event(key, lparam));
    return S_OK;
}

HRESULT STDMETHODCALLTYPE KeyEventSink::OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) {
    if (!eaten) return E_POINTER;
    *eaten = FALSE;
    return S_OK;
}

HRESULT STDMETHODCALLTYPE KeyEventSink::OnKeyDown(ITfContext*, WPARAM key, LPARAM lparam, BOOL* eaten) {
    if (!eaten) return E_POINTER;
    *eaten = handler_ != nullptr && handler_->handle(make_event(key, lparam));
    return S_OK;
}

HRESULT STDMETHODCALLTYPE KeyEventSink::OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) {
    if (!eaten) return E_POINTER;
    *eaten = FALSE;
    return S_OK;
}

HRESULT STDMETHODCALLTYPE KeyEventSink::OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) {
    if (!eaten) return E_POINTER;
    *eaten = FALSE;
    return S_OK;
}

} // namespace skey::windows
#endif
