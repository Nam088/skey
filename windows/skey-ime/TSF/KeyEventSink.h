#pragma once

#ifdef _WIN32
#include <windows.h>
#include <msctf.h>
#include "IKeyEventHandler.h"

namespace skey::windows {

class KeyEventSink final : public ITfKeyEventSink {
public:
    explicit KeyEventSink(IKeyEventHandler* handler = nullptr) noexcept : handler_(handler) {}
    void set_handler(IKeyEventHandler* handler) noexcept { handler_ = handler; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
    ULONG STDMETHODCALLTYPE AddRef() override;
    ULONG STDMETHODCALLTYPE Release() override;
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL foreground) override;
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnKeyDown(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) override;

private:
    ~KeyEventSink() = default;
    LONG references_{1};
    IKeyEventHandler* handler_{nullptr};
};

} // namespace skey::windows
#endif
