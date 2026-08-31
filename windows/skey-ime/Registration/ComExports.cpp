#ifdef _WIN32
#include "ComExports.h"
#include "ClassFactory.h"
#include "Guids.h"
#include "ProfileRegistrar.h"

#include <new>

using namespace skey::windows;

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** object) {
    if (object == nullptr) return E_POINTER;
    *object = nullptr;

    if (clsid != CLSID_SKeyTextService) return CLASS_E_CLASSNOTAVAILABLE;

    auto* factory = new (std::nothrow) ClassFactory();
    if (factory == nullptr) return E_OUTOFMEMORY;

    const HRESULT hr = factory->QueryInterface(riid, object);
    factory->Release();
    return hr;
}

STDAPI DllCanUnloadNow() {
    return g_moduleRef.load() == 0 ? S_OK : S_FALSE;
}

STDAPI DllRegisterServer() {
    return RegisterTextService(g_hInstance);
}

STDAPI DllUnregisterServer() {
    return UnregisterTextService();
}

#endif
