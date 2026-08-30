#ifdef _WIN32
#include <windows.h>
#include <msctf.h>
#include "ProfileRegistrar.h"

namespace skey::windows {
HRESULT RegisterTextService(HINSTANCE) noexcept { return S_OK; }
HRESULT UnregisterTextService() noexcept { return S_OK; }
} // namespace skey::windows
#endif
