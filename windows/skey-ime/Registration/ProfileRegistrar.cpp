#ifdef _WIN32
#include <windows.h>
#include <msctf.h>
#include "ProfileRegistrar.h"
#include "Guids.h"

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
    ITfInputProcessorProfileMgr* profile_mgr = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfInputProcessorProfileMgr,
                                  reinterpret_cast<void**>(&profile_mgr));
    if (FAILED(hr)) return hr;

    hr = profile_mgr->AddProfile(CLSID_SKeyTextService, kVietnameseLangId, GUID_SKeyLanguageProfile,
                                  kTextServiceDescription, kLanguageProfileDescription,
                                  nullptr, 0, nullptr, 0, 0);
    profile_mgr->Release();
    if (FAILED(hr)) return hr;

    hr = register_category();
    if (FAILED(hr)) {
        CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                         IID_ITfInputProcessorProfileMgr,
                         reinterpret_cast<void**>(&profile_mgr));
        if (profile_mgr != nullptr) {
            profile_mgr->RemoveProfile(kVietnameseLangId, CLSID_SKeyTextService,
                                        GUID_SKeyLanguageProfile);
            profile_mgr->Release();
        }
        return hr;
    }

    (void)module;
    return S_OK;
}

HRESULT UnregisterTextService() noexcept {
    ITfInputProcessorProfileMgr* profile_mgr = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_ITfInputProcessorProfileMgr,
                                  reinterpret_cast<void**>(&profile_mgr));
    if (SUCCEEDED(hr)) {
        profile_mgr->RemoveProfile(kVietnameseLangId, CLSID_SKeyTextService,
                                    GUID_SKeyLanguageProfile);
        profile_mgr->Release();
    }

    unregister_category();
    return S_OK;
}

} // namespace skey::windows
#endif
