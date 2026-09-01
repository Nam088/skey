#pragma once

#include <cstdint>

namespace skey::windows {

// Port of platforms/macos/.../KeyConstants.swift KeyCategory.
enum class KeyCategory : uint8_t {
    character,
    backspace,
    navigation,
    word_break,
    function_or_media,
    modifier,
};

// O(1) virtual-key classification table, ported from the macOS
// KeyClassifier LUT (KeyConstants.swift). VK codes are 8-bit, so the
// table covers all 256 entries.
class KeyClassifier {
public:
    static KeyCategory classify(unsigned vk) noexcept {
        return vk < 256 ? table()[vk] : KeyCategory::character;
    }

private:
    static const KeyCategory* table() noexcept;
};

} // namespace skey::windows
