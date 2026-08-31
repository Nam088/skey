#ifdef _WIN32
#include "TsfTextService.h"
#include "KeyEventSink.h"
#include "../Host/TsfTextHost.h"
#include "../Service/WindowsImeService.h"

#include <new>

namespace skey::windows {

HRESULT STDMETHODCALLTYPE TsfTextService::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (riid == IID_IUnknown || riid == IID_ITfTextInputProcessor) {
        *object = static_cast<ITfTextInputProcessor*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE TsfTextService::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&references_));
}

ULONG STDMETHODCALLTYPE TsfTextService::Release() {
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&references_));
    if (count == 0) delete this;
    return count;
}

HRESULT STDMETHODCALLTYPE TsfTextService::Activate(ITfThreadMgr* thread_manager, TfClientId client_id) {
    if (thread_manager == nullptr) return E_INVALIDARG;
    if (active_) return S_FALSE;
    thread_manager_ = thread_manager;
    thread_manager_->AddRef();
    client_id_ = client_id;
    active_ = true;
    return S_OK;
}

void TsfTextService::detach_sink() noexcept {
    if (key_sink_ != nullptr) {
        if (advised_source_ != nullptr) {
            advised_source_->UnadviseSink(sink_cookie_);
            advised_source_->Release();
            advised_source_ = nullptr;
        }
        key_sink_->Release();
        key_sink_ = nullptr;
        sink_cookie_ = TF_INVALID_COOKIE;
    }
    service_.reset();
    text_host_.reset();
}

HRESULT TsfTextService::AttachKeyEventSink(ITfContext* context) noexcept {
    if (!active_ || context == nullptr) return E_INVALIDARG;
    if (sink_cookie_ != TF_INVALID_COOKIE) return S_FALSE;

    ITfSource* source = nullptr;
    HRESULT hr = context->QueryInterface(IID_ITfSource, reinterpret_cast<void**>(&source));
    if (FAILED(hr)) return hr;

    text_host_ = std::make_unique<TsfTextHost>(context);
    service_ = std::make_unique<WindowsImeService>(*text_host_);

    key_sink_ = new (std::nothrow) KeyEventSink();
    if (key_sink_ == nullptr) {
        service_.reset();
        text_host_.reset();
        source->Release();
        return E_OUTOFMEMORY;
    }
    key_sink_->set_handler(&service_->key_handler());

    hr = source->AdviseSink(IID_ITfKeyEventSink, key_sink_, &sink_cookie_);
    if (SUCCEEDED(hr)) {
        advised_source_ = source;
    } else {
        key_sink_->set_handler(nullptr);
        key_sink_->Release();
        key_sink_ = nullptr;
        service_.reset();
        text_host_.reset();
        source->Release();
        sink_cookie_ = TF_INVALID_COOKIE;
    }
    return hr;
}

HRESULT STDMETHODCALLTYPE TsfTextService::Deactivate() {
    if (!active_) return S_FALSE;
    detach_sink();
    active_ = false;
    client_id_ = TF_CLIENTID_NULL;
    if (thread_manager_ != nullptr) {
        thread_manager_->Release();
        thread_manager_ = nullptr;
    }
    return S_OK;
}

} // namespace skey::windows
#endif
