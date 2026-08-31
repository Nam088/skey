#ifdef _WIN32
#include <windows.h>
#include <msctf.h>
#include "ProfileRegistrar.h"
#include "Guids.h"

// TF_TFCAT_TIP_KEYBOARD is defined in newer Windows SDKs
// For compatibility, define it if not present
#ifndef TF_TFCAT_TIP_KEYBOARD
DEFINE_GUID(GUID_TFCAT_TIP_KEYBOARD, 0x00000001, 0x1000, 0x1000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01);
#define TF_TFCAT_TIP_KEYBOARD GUID_TFCAT_TIP_KEYBOARD
#endif

namespace skey::windows {

namespace {

HRESULT register_category() {
    ITfCategoryMgr* category_mgr = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfCategoryMgr, reinterpret_cast<void**>(&category_mgr));
    if (FAILED(hr)) return hr;

    hr = category_mgr->RegisterCategory(CLSID_SKeyTextService, TF_TFCAT_TIP_KEYBOARD,
                                         CLSID_SKeyTextService);
    category_mgr->Release();
    return hr;
}

HRESULT unregister_category() {
    ITfCategoryMgr* category_mgr = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfCategoryMgr, reinterpret_cast<void**>(&category_mgr));
    if (FAILED(hr)) return hr;

    hr = category_mgr->UnregisterCategory(CLSID_SKeyTextService, TF_TFCAT_TIP_KEYBOARD,
                                           CLSID_SKeyTextService);
    category_mgr->Release();
    return hr;
}

} // namespace

HRESULT RegisterTextService(HINSTANCE module) noexcept {
    ITfInputProcessorProfiles* profiles = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfInputProcessorProfiles,
                                  reinterpret_cast<void**>(&profiles));
    if (FAILED(hr)) return hr;

    hr = profiles->Register(CLSID_SKeyTextService);
    profiles->Release();
    if (FAILED(hr)) return hr;

    hr = register_category();
    if (FAILED(hr)) {
        CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                         IID_ITfInputProcessorProfiles,
                         reinterpret_cast<void**>(&profiles));
        if (profiles != nullptr) {
            profiles->Unregister(CLSID_SKeyTextService);
            profiles->Release();
        }
        return hr;
    }

    (void)module;
    return S_OK;
}

HRESULT UnregisterTextService() noexcept {
    ITfInputProcessorProfiles* profiles = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfInputProcessorProfiles,
                                  reinterpret_cast<void**>(&profiles));
    if (SUCCEEDED(hr)) {
        profiles->Unregister(CLSID_SKeyTextService);
        profiles->Release();
    }

    unregister_category();
    return S_OK;
}

} // namespace skey::windows
#endif
