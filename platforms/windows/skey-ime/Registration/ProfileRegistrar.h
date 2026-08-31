#pragma once

#ifdef _WIN32
#include <windows.h>

namespace skey::windows {

// Registration entry points are kept explicit so the installer and tests can
// invoke them without depending on UI processes.
HRESULT RegisterTextService(HINSTANCE module) noexcept;
HRESULT UnregisterTextService() noexcept;

} // namespace skey::windows
#endif
