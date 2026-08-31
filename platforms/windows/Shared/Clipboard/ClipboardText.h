#pragma once

#include <cstdint>
#include <string>

namespace skey::windows {

// Pure helpers for clipboard history search, mirrored from the macOS
// ClipboardItem.vietnameseFold + SearchRanking logic.
class ClipboardText {
public:
    // Case + diacritic folding with Vietnamese specifics (đ/Đ -> d/D).
    // Result is lowercase ASCII-ish base letters; non-Latin code points
    // pass through unchanged as UTF-8.
    static std::string fold(const std::string& utf8);

    // Ranked search, mirroring macOS SearchRanking:
    //   exact-case substring:  2'000'000 - position
    //   folded substring:      1'000'000 - position
    //   folded subsequence:    0
    //   no match:              -1
    static long long rank(const std::string& text,
                          const std::string& folded_text,
                          const std::string& query);

    static std::string sha256_hex(const std::string& data);

    static bool is_blank(const std::string& utf8);
};

} // namespace skey::windows
