#include "ApplyEditSession.h"

CApplyEditSession::CApplyEditSession(ITfContext* context, int backspaces, const wchar_t* text)
    : context_(context), backspaces_(backspaces), text_(text) {
    if (context_ != nullptr) context_->AddRef();
}

HRESULT CApplyEditSession::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_ITfEditSession) {
        *object = static_cast<ITfEditSession*>(this);
        AddRef();
        return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
}

ULONG CApplyEditSession::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&refs_));
}

ULONG CApplyEditSession::Release() {
    const long remaining = InterlockedDecrement(&refs_);
    if (remaining == 0) delete this;
    return static_cast<ULONG>(remaining);
}

HRESULT CApplyEditSession::DoEditSession(TfEditCookie ec) {
    if (context_ == nullptr) return E_FAIL;

    // Start from the current selection (empty range == caret).
    ITfRange* range = nullptr;
    ULONG fetched = 0;
    HRESULT hr = context_->GetSelection(ec, TF_DEFAULT_SELECTION, 1, &range, &fetched);
    if (FAILED(hr) || fetched == 0 || range == nullptr) {
        ITfInsertAtSelection* insert = nullptr;
        if (SUCCEEDED(context_->QueryInterface(IID_ITfInsertAtSelection,
                                               reinterpret_cast<void**>(&insert)))) {
            hr = insert->InsertTextAtSelection(ec, TF_IAS_QUERYONLY, nullptr, 0, &range);
            insert->Release();
        }
        if (FAILED(hr) || range == nullptr) {
            if (range != nullptr) range->Release();
            return E_FAIL;
        }
    }

    if (backspaces_ > 0) {
        LONG shifted = 0;
        range->ShiftStart(ec, -static_cast<LONG>(backspaces_), TF_ANCHOR_START, &shifted);
    }

    hr = range->SetText(ec, 0, text_.c_str(), static_cast<LONG>(text_.size()));
    if (SUCCEEDED(hr)) {
        // Park the caret right after the replaced text.
        range->Collapse(ec, TF_ANCHOR_END);
        TF_SELECTION selection{};
        selection.range = range;
        selection.style.ase = TF_AE_NONE;
        selection.style.fInterimChar = FALSE;
        context_->SetSelection(ec, 1, &selection);
    }

    range->Release();
    return hr;
}
