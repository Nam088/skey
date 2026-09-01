#pragma once

#include <msctf.h>

#include <string>

// Applies one bridge edit ({backspaces, text}) at the current selection of
// the focused TSF context: replaces the text before the caret and moves the
// caret to the end of the insertion. Runs inside an edit session requested
// from the text service's window handler.
class CApplyEditSession final : public ITfEditSession {
public:
    CApplyEditSession(ITfContext* context, int backspaces, const wchar_t* text);

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** object) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    // ITfEditSession
    STDMETHODIMP DoEditSession(TfEditCookie ec) override;

private:
    long refs_{1};
    ITfContext* context_;
    int backspaces_;
    std::wstring text_;
};
