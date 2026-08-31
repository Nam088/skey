#pragma once

#include <string>
#include <vector>

#include "../../Shared/Contracts/SettingsModel.h"
#include "../../Shared/Translator/TranslatorService.h"

namespace skey::windows {

struct TranslationHudConfig {
    std::vector<TranslatorEngine> engines;
    std::string target_language{"vi"};
    bool auto_detect{true};
};

// Quick-translate HUD (Alt+T), mirroring macOS: opens empty near the cursor,
// user types, Enter/Translate runs the engine cascade, result + engine +
// latency shown, Esc closes. Runs a modal loop on the calling thread.
class TranslationHud {
public:
    static void show(TranslationHudConfig config, TranslatorService::HttpFn http);
};

} // namespace skey::windows
