#ifdef _WIN32
#include "KeyEventSink.h"
namespace skey::windows {
HRESULT STDMETHODCALLTYPE KeyEventSink::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (riid == IID_IUnknown || riid == IID_ITfKeyEventSink) { *object = static_cast<ITfKeyEventSink*>(this); AddRef(); return S_OK; }
    return E_NOINTERFACE;
}
ULONG STDMETHODCALLTYPE KeyEventSink::AddRef() { return static_cast<ULONG>(InterlockedIncrement(&references_)); }
ULONG STDMETHODCALLTYPE KeyEventSink::Release() { const ULONG count = static_cast<ULONG>(InterlockedDecrement(&references_)); if (count == 0) delete this; return count; }
namespace {
bool is_navigation(WPARAM key) noexcept {
    return key == VK_ESCAPE || key == VK_LEFT || key == VK_RIGHT || key == VK_UP || key == VK_DOWN ||
           key == VK_HOME || key == VK_END || key == VK_PRIOR || key == VK_NEXT;
}

KeyEvent make_event(WPARAM key, LPARAM lparam) noexcept {
    KeyEvent event{};
    event.key_code = static_cast<std::uint32_t>(key);
    event.repeat = (lparam & 0x40000000) != 0;
    if (key == VK_BACK) event.kind = EventKind::backspace;
    else if (key == VK_SPACE || key == VK_RETURN || key == VK_TAB) event.kind = EventKind::word_break;
    else if (is_navigation(key)) event.kind = EventKind::navigation;
    else event.kind = EventKind::key_down;
    // ASCII virtual-key codes are stable for the common A-Z/0-9 range.
    event.codepoint = key >= 'A' && key <= 'Z' ? static_cast<std::uint32_t>(key + ('a' - 'A')) : static_cast<std::uint32_t>(key);
    return event;
}
}

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
HRESULT STDMETHODCALLTYPE KeyEventSink::OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) { if (!eaten) return E_POINTER; *eaten = FALSE; return S_OK; }
} // namespace skey::windows
#endif
