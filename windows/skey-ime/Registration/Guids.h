#pragma once

#ifdef _WIN32
#include <windows.h>

namespace skey::windows {

inline constexpr wchar_t kTextServiceDisplayName[] = L"SKey Vietnamese";
inline constexpr wchar_t kTextServiceDescription[] = L"SKey Vietnamese Input Method";
inline constexpr wchar_t kLanguageProfileDescription[] = L"SKey";

extern const GUID CLSID_SKeyTextService;
extern const GUID GUID_SKeyLanguageProfile;

inline constexpr LANGID kVietnameseLangId = MAKELANGID(LANG_VIETNAMESE, SUBLANG_DEFAULT);

} // namespace skey::windows

extern HINSTANCE g_hInstance;
extern std::atomic<LONG> g_moduleRef;

#endif
