// COM server registration for skey-tsf.dll.
//
// DllRegisterServer writes three things:
//   1. Software\Classes\CLSID\{...}\InprocServer32   (HKLM, HKCU fallback)
//   2. TF_CAT_TSF_TIP category via ITfCategoryMgr    (needs HKLM)
//   3. the "SKey Vietnamese" language profile via
//      ITfInputProcessorProfiles                     (HKCU)
// The installer runs regsvr32 twice: once in system context (1 + 2) and once
// impersonated (3); each part ignores the other's failures.

#include <msctf.h>
#include <olectl.h>

#include <cstring>
#include <string>

#include "SKeyTsfGlobals.h"
#include "SKeyTsfGuids.h"

namespace {

std::wstring guid_string(const GUID& guid) {
    wchar_t buffer[64]{};
    StringFromGUID2(guid, buffer, static_cast<int>(std::size(buffer)));
    return buffer;
}

// HKLM when elevated, HKCU otherwise.
HKEY classes_root() {
    HKEY probe = nullptr;
    const LONG rc = RegCreateKeyExW(HKEY_LOCAL_MACHINE, L"Software\\Classes", 0, nullptr, 0,
                                    KEY_WRITE, nullptr, &probe, nullptr);
    if (rc == ERROR_SUCCESS) {
        RegCloseKey(probe);
        return HKEY_LOCAL_MACHINE;
    }
    return HKEY_CURRENT_USER;
}

bool set_string(HKEY root, const std::wstring& subkey, const wchar_t* value_name,
                const std::wstring& data) {
    return RegSetKeyValueW(root, subkey.c_str(), value_name, REG_SZ, data.c_str(),
                           static_cast<DWORD>((data.size() + 1) * sizeof(wchar_t))) == ERROR_SUCCESS;
}

bool register_clsid_entries() {
    wchar_t module_path[MAX_PATH]{};
    if (GetModuleFileNameW(g_skey_tsf_module, module_path, MAX_PATH) == 0) return false;

    const std::wstring clsid_key = L"Software\\Classes\\CLSID\\" + guid_string(CLSID_SKeyTextService);
    const HKEY root = classes_root();
    bool ok = set_string(root, clsid_key, nullptr, L"SKey Vietnamese Input Method");
    ok = ok && set_string(root, clsid_key + L"\\InprocServer32", nullptr, module_path);
    ok = ok && set_string(root, clsid_key + L"\\InprocServer32", L"ThreadingModel", L"Apartment");
    return ok;
}

void register_categories() {
    ITfCategoryMgr* categories = nullptr;
    const HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                        IID_ITfCategoryMgr,
                                        reinterpret_cast<void**>(&categories));
    if (FAILED(hr)) return;  // needs elevation; the system-context pass does it
    categories->RegisterCategory(CLSID_SKeyTextService, GUID_SKeyTsfTipCategory,
                                 CLSID_SKeyTextService);
    categories->Release();
}

void register_profile() {
    ITfInputProcessorProfiles* profiles = nullptr;
    const HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr,
                                        CLSCTX_INPROC_SERVER, IID_ITfInputProcessorProfiles,
                                        reinterpret_cast<void**>(&profiles));
    if (FAILED(hr)) return;

    constexpr LANGID kVietnamese = MAKELANGID(LANG_VIETNAMESE, SUBLANG_DEFAULT);
    const wchar_t* description = L"SKey Vietnamese";
    profiles->Register(CLSID_SKeyTextService);
    profiles->AddLanguageProfile(CLSID_SKeyTextService, kVietnamese, GUID_SKeyProfile, description,
                                 static_cast<ULONG>(std::wcslen(description)), nullptr, 0, 0);
    profiles->EnableLanguageProfile(CLSID_SKeyTextService, kVietnamese, GUID_SKeyProfile, TRUE);
    profiles->Release();
}

void unregister_profile() {
    ITfInputProcessorProfiles* profiles = nullptr;
    const HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr,
                                        CLSCTX_INPROC_SERVER, IID_ITfInputProcessorProfiles,
                                        reinterpret_cast<void**>(&profiles));
    if (FAILED(hr)) return;
    constexpr LANGID kVietnamese = MAKELANGID(LANG_VIETNAMESE, SUBLANG_DEFAULT);
    profiles->EnableLanguageProfile(CLSID_SKeyTextService, kVietnamese, GUID_SKeyProfile, FALSE);
    profiles->Unregister(CLSID_SKeyTextService);
    profiles->Release();
}

void unregister_categories() {
    ITfCategoryMgr* categories = nullptr;
    const HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                        IID_ITfCategoryMgr,
                                        reinterpret_cast<void**>(&categories));
    if (FAILED(hr)) return;
    categories->UnregisterCategory(CLSID_SKeyTextService, GUID_SKeyTsfTipCategory,
                                   CLSID_SKeyTextService);
    categories->Release();
}

} // namespace

STDAPI DllRegisterServer() {
    register_profile();        // HKCU, works un-privileged
    register_categories();     // HKLM, best effort
    if (!register_clsid_entries()) return SELFREG_E_CLASS;
    return S_OK;
}

STDAPI DllUnregisterServer() {
    unregister_profile();
    unregister_categories();
    const std::wstring clsid_key = L"Software\\Classes\\CLSID\\" + guid_string(CLSID_SKeyTextService);
    RegDeleteTreeW(HKEY_LOCAL_MACHINE, clsid_key.c_str());
    RegDeleteTreeW(HKEY_CURRENT_USER, clsid_key.c_str());
    return S_OK;
}
