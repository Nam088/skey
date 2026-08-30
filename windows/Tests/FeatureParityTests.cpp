#include "../skey-settings/Features/Cleaner/CleanerFeature.h"
#include "../skey-settings/Features/Clipboard/ClipboardFeature.h"
#include "../skey-settings/Features/Keyboard/KeyboardFeature.h"
#include "../skey-settings/Features/Clipboard/Services/ClipboardService.h"
#include "../skey-settings/Features/Translator/Services/TranslatorService.h"
#include "../skey-settings/Features/Settings/UI/Tabs/SettingsTabs.h"
#include <cassert>
int main() {
    skey::windows::CleanerFeature cleaner;
    skey::windows::ClipboardFeature clipboard;
    skey::windows::KeyboardFeature keyboard;
    skey::windows::ClipboardService service;
    skey::windows::TranslatorService translator;
    assert(!cleaner.locked && clipboard.max_items > 0 && keyboard.spell_check);
    service.clear();
    assert(service.items().empty());
    assert(translator.translate("hello").source == "hello");
    assert(static_cast<int>(skey::windows::SettingsTab::about) >= 0);
    return 0;
}
