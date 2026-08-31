#ifdef _WIN32
#include <windows.h>
#include <initguid.h>
#include "Guids.h"

namespace skey::windows {

// {FCD38A14-DB67-4B3D-BBA8-8B28E0141DA9}
DEFINE_GUID(CLSID_SKeyTextService,
    0xfcd38a14, 0xdb67, 0x4b3d, 0xbb, 0xa8, 0x8b, 0x28, 0xe0, 0x14, 0x1d, 0xa9);

// {A9B61735-48E6-4FC0-AE7F-BEABDE5653B2}
DEFINE_GUID(GUID_SKeyLanguageProfile,
    0xa9b61735, 0x48e6, 0x4fc0, 0xae, 0x7f, 0xbe, 0xab, 0xde, 0x56, 0x53, 0xb2);

} // namespace skey::windows
#endif
