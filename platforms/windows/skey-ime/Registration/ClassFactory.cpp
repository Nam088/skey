#ifdef _WIN32
#include "ClassFactory.h"
#include "Guids.h"
#include "../TSF/TsfTextService.h"

#include <new>

namespace skey::windows {

HRESULT STDMETHODCALLTYPE ClassFactory::QueryInterface(REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (riid == IID_IUnknown || riid == IID_IClassFactory) {
        *object = static_cast<IClassFactory*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE ClassFactory::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&references_));
}

ULONG STDMETHODCALLTYPE ClassFactory::Release() {
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&references_));
    if (count == 0) delete this;
    return count;
}

HRESULT STDMETHODCALLTYPE ClassFactory::CreateInstance(IUnknown* outer, REFIID riid, void** object) {
    if (outer != nullptr) return CLASS_E_NOAGGREGATION;
    if (object == nullptr) return E_POINTER;

    auto* service = new (std::nothrow) TsfTextService();
    if (service == nullptr) return E_OUTOFMEMORY;

    const HRESULT hr = service->QueryInterface(riid, object);
    service->Release();
    return hr;
}

HRESULT STDMETHODCALLTYPE ClassFactory::LockServer(BOOL lock) {
    if (lock)
        g_moduleRef.fetch_add(1, std::memory_order_relaxed);
    else
        g_moduleRef.fetch_sub(1, std::memory_order_relaxed);
    return S_OK;
}

} // namespace skey::windows
#endif
