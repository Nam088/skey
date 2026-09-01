#include "KeyClassifier.h"

#include <initializer_list>

namespace skey::windows {

namespace {

// Windows virtual key codes used by the classifier. Declared locally so
// this module stays header-usable without <windows.h> (tests run on all
// platforms).
constexpr unsigned kVkBack = 0x08;
constexpr unsigned kVkTab = 0x09;
constexpr unsigned kVkReturn = 0x0D;
constexpr unsigned kVkEscape = 0x1B;
constexpr unsigned kVkSpace = 0x20;
constexpr unsigned kVkPrior = 0x21;
constexpr unsigned kVkNext = 0x22;
constexpr unsigned kVkEnd = 0x23;
constexpr unsigned kVkHome = 0x24;
constexpr unsigned kVkLeft = 0x25;
constexpr unsigned kVkUp = 0x26;
constexpr unsigned kVkRight = 0x27;
constexpr unsigned kVkDown = 0x28;
constexpr unsigned kVkDelete = 0x2E;
constexpr unsigned kVkHelp = 0x2F;
constexpr unsigned kVkShift = 0x10;
constexpr unsigned kVkControl = 0x11;
constexpr unsigned kVkMenu = 0x12;
constexpr unsigned kVkCapital = 0x14;
constexpr unsigned kVkLWin = 0x5B;
constexpr unsigned kVkRWin = 0x5C;
constexpr unsigned kVkLShift = 0xA0;
constexpr unsigned kVkRShift = 0xA1;
constexpr unsigned kVkLControl = 0xA2;
constexpr unsigned kVkRControl = 0xA3;
constexpr unsigned kVkLMenu = 0xA4;
constexpr unsigned kVkRMenu = 0xA5;
constexpr unsigned kVkF1 = 0x70;
constexpr unsigned kVkF24 = 0x87;
constexpr unsigned kVkBrowserBack = 0xA6;
constexpr unsigned kVkLaunchApp2 = 0xB7;

KeyCategory build_table[256];

struct TableInit {
    TableInit() {
        for (auto& c : build_table) c = KeyCategory::character;

        build_table[kVkBack] = KeyCategory::backspace;

        // Navigation
        for (unsigned vk : {kVkLeft, kVkRight, kVkUp, kVkDown, kVkHome,
                            kVkEnd, kVkPrior, kVkNext, kVkDelete, kVkEscape}) {
            build_table[vk] = KeyCategory::navigation;
        }

        // Word breaks (VK_RETURN covers both main Return and keypad Enter)
        for (unsigned vk : {kVkReturn, kVkTab, kVkSpace}) {
            build_table[vk] = KeyCategory::word_break;
        }

        // Modifiers
        for (unsigned vk : {kVkShift, kVkControl, kVkMenu, kVkCapital,
                            kVkLWin, kVkRWin, kVkLShift, kVkRShift,
                            kVkLControl, kVkRControl, kVkLMenu, kVkRMenu}) {
            build_table[vk] = KeyCategory::modifier;
        }

        // Function keys F1-F24
        for (unsigned vk = kVkF1; vk <= kVkF24; ++vk) {
            build_table[vk] = KeyCategory::function_or_media;
        }

        // Browser / volume / media / launch keys: contiguous 0xA6..0xB7
        for (unsigned vk = kVkBrowserBack; vk <= kVkLaunchApp2; ++vk) {
            build_table[vk] = KeyCategory::function_or_media;
        }
        build_table[kVkHelp] = KeyCategory::function_or_media;
    }
};

} // namespace

const KeyCategory* KeyClassifier::table() noexcept {
    static const TableInit init;
    return build_table;
}

} // namespace skey::windows
