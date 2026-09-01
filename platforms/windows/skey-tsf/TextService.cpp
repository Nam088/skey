#include "TextService.h"

#include <new>

#include "ApplyEditSession.h"
#include "BridgeServer.h"
#include "SKeyTsfGlobals.h"

namespace {
constexpr const wchar_t* kWindowClassName = L"SKeyTsfBridgeWindow";
}

CTextService::~CTextService() = default;

HRESULT CTextService::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_ITfTextInputProcessor) {
        *object = static_cast<ITfTextInputProcessor*>(this);
        AddRef();
        return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
}

ULONG CTextService::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&refs_));
}

ULONG CTextService::Release() {
    const long remaining = InterlockedDecrement(&refs_);
    if (remaining == 0) delete this;
    return static_cast<ULONG>(remaining);
}

ATOM CTextService::EnsureWindowClass() {
    static const ATOM atom = [] {
        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = &CTextService::WndProcThunk;
        wc.hInstance = g_skey_tsf_module;
        wc.lpszClassName = kWindowClassName;
        return RegisterClassExW(&wc);
    }();
    return atom;
}

HRESULT CTextService::Activate(ITfThreadMgr* thread_mgr, TfClientId client_id) {
    if (thread_mgr == nullptr) return E_INVALIDARG;
    thread_mgr_ = thread_mgr;
    thread_mgr_->AddRef();
    client_id_ = client_id;

    // Message-only window on the activating (UI) thread: edit sessions must
    // be requested from the thread that owns the TSF context.
    if (EnsureWindowClass() != 0) {
        window_ = CreateWindowExW(0, kWindowClassName, L"", 0, 0, 0, 0, 0,
                                  HWND_MESSAGE, nullptr, g_skey_tsf_module, this);
        if (window_ != nullptr) {
            SetWindowLongPtrW(window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
            skey::tsf::BridgeServer::attach(window_);
        }
    }
    return S_OK;
}

HRESULT CTextService::Deactivate() {
    if (window_ != nullptr) {
        skey::tsf::BridgeServer::detach();
        SetWindowLongPtrW(window_, GWLP_USERDATA, 0);
        DestroyWindow(window_);
        window_ = nullptr;
    }
    if (thread_mgr_ != nullptr) {
        thread_mgr_->Release();
        thread_mgr_ = nullptr;
    }
    client_id_ = TF_CLIENTID_NULL;
    return S_OK;
}

LRESULT CALLBACK CTextService::WndProcThunk(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    if (message == WM_NCCREATE) {
        const auto* create = reinterpret_cast<const CREATESTRUCTW*>(lparam);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create->lpCreateParams));
    }
    auto* self = reinterpret_cast<CTextService*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (self != nullptr) {
        return self->WndProc(window, message, wparam, lparam);
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

LRESULT CTextService::WndProc(HWND window, UINT message, WPARAM, LPARAM lparam) {
    using skey::tsf::kSKeyTsfApplyMessage;
    if (message == kSKeyTsfApplyMessage) {
        const auto* msg = reinterpret_cast<const skey::tsf::BridgeApplyMsg*>(lparam);
        if (msg == nullptr) return 0;
        ApplyEdit(msg->backspaces, msg->text);
        return 1;  // applied; echoed back to the EXE as status 0
    }
    return DefWindowProcW(window, message, 0, lparam);
}

void CTextService::ApplyEdit(int backspaces, const wchar_t* text) {
    if (thread_mgr_ == nullptr) return;

    ITfDocumentMgr* document = nullptr;
    if (FAILED(thread_mgr_->GetFocus(&document)) || document == nullptr) return;
    ITfContext* context = nullptr;
    const HRESULT context_hr = document->GetTop(&context);
    document->Release();
    if (FAILED(context_hr) || context == nullptr) return;

    auto* session = new (std::nothrow) CApplyEditSession(context, backspaces, text);
    if (session != nullptr) {
        HRESULT session_hr = E_FAIL;
        HRESULT request_hr = context->RequestEditSession(
            client_id_, session, TF_ES_READWRITE | TF_ES_ASYNC, &session_hr);
        // Some hosts refuse async read/write sessions; fall back to sync.
        if (FAILED(request_hr) || session_hr == TF_E_SYNCHRONOUS) {
            context->RequestEditSession(client_id_, session, TF_ES_READWRITE | TF_ES_SYNC,
                                        &session_hr);
        }
        session->Release();
    }
    context->Release();
}
