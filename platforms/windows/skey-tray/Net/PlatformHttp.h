#pragma once

#include "../../Shared/Translator/TranslatorService.h"

namespace skey::windows {

// Synchronous WinHTTP transport shared by TranslatorService and the update
// checker. Returns nullptr on non-Windows builds.
TranslatorService::HttpFn make_platform_http();

} // namespace skey::windows
