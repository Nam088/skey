// Single translation unit owning the GUID storage for skey-tsf.dll.
#include <initguid.h>

#include <msctf.h>

#include "SKeyTsfGuids.h"

// {7E5F3A2C-61B4-4D8E-9C37-2A5B8D40F6E1}
DEFINE_GUID(CLSID_SKeyTextService,
            0x7E5F3A2C, 0x61B4, 0x4D8E, 0x9C, 0x37, 0x2A, 0x5B, 0x8D, 0x40, 0xF6, 0xE1);

// {4B9C1D7E-8F2A-4E63-B5D0-9C7A3E1F2B48}
DEFINE_GUID(GUID_SKeyProfile,
            0x4B9C1D7E, 0x8F2A, 0x4E63, 0xB5, 0xD0, 0x9C, 0x7A, 0x3E, 0x1F, 0x2B, 0x48);
