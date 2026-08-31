#include "ClassFactory.h"

#include <new>

#include "SKeyTsfGuids.h"
#include "TextService.h"

HRESULT CClassFactory::CreateInstance(IUnknown* outer, REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (outer != nullptr) return CLASS_E_NOAGGREGATION;

    auto* service = new (std::nothrow) CTextService();
    if (service == nullptr) return E_OUTOFMEMORY;

    const HRESULT hr = service->QueryInterface(riid, object);
    service->Release();
    return hr;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;
    if (rclsid != CLSID_SKeyTextService) return CLASS_E_CLASSNOTAVAILABLE;

    auto* factory = new (std::nothrow) CClassFactory();
    if (factory == nullptr) return E_OUTOFMEMORY;
    const HRESULT hr = factory->QueryInterface(riid, object);
    factory->Release();
    return hr;
}

STDAPI DllCanUnloadNow() {
    return g_skey_tsf_locks.load() == 0 ? S_OK : S_FALSE;
}
