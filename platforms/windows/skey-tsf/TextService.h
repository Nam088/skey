#pragma once

#include <msctf.h>

// Minimal TSF text service hosting the bridge window. It owns no keystroke
// sink and no composition: skey-tray.exe keeps doing all input handling and
// only pushes finished edits, which this service applies at the caret via
// CApplyEditSession. Being a registered TIP is what lets it load inside
// browsers so the edits happen inside their own TSF document.
class CTextService final : public ITfTextInputProcessor {
public:
    CTextService() = default;
    ~CTextService();

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** object) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    // ITfTextInputProcessor
    STDMETHODIMP Activate(ITfThreadMgr* thread_mgr, TfClientId client_id) override;
    STDMETHODIMP Deactivate() override;

private:
    static LRESULT CALLBACK WndProcThunk(HWND window, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT WndProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);
    void ApplyEdit(int backspaces, const wchar_t* text);
    static ATOM EnsureWindowClass();

    long refs_{1};
    ITfThreadMgr* thread_mgr_{nullptr};
    TfClientId client_id_{TF_CLIENTID_NULL};
    HWND window_{nullptr};
};
