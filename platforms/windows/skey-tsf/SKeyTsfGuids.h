#pragma once

#include <objbase.h>

// Must match kSKeyTsfClsid / kSKeyTsfProfile in Shared/TsfBridge/TsfBridge.h.
EXTERN_C const CLSID CLSID_SKeyTextService;
EXTERN_C const GUID GUID_SKeyProfile;
// Same value as GUID_TFCAT_TSF_TIP; defined here because recent Windows SDKs
// no longer declare the TSF category GUIDs from msctf.h.
EXTERN_C const GUID GUID_SKeyTsfTipCategory;
