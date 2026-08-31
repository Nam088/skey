// Golden typing vectors from shared/contracts/typing-vectors/basic.json,
// driven through the real Rust engine (requires skey.lib).
#include "../skey-tray/Engine/SKeyEngineWrapper.h"

#include <cassert>
#include <string>

using namespace skey::windows;

namespace {

std::u32string to_codepoints(const std::string& utf8) {
    std::u32string out;
    std::size_t i = 0;
    while (i < utf8.size()) {
        const auto b0 = static_cast<unsigned char>(utf8[i]);
        char32_t cp = 0;
        int extra = 0;
        if (b0 < 0x80) cp = b0;
        else if ((b0 & 0xE0) == 0xC0) { cp = b0 & 0x1F; extra = 1; }
        else if ((b0 & 0xF0) == 0xE0) { cp = b0 & 0x0F; extra = 2; }
        else if ((b0 & 0xF8) == 0xF0) { cp = b0 & 0x07; extra = 3; }
        else { ++i; continue; }
        for (int k = 1; k <= extra && i + k < utf8.size(); ++k) {
            cp = (cp << 6) | (static_cast<unsigned char>(utf8[i + k]) & 0x3F);
        }
        i += extra + 1;
        out.push_back(cp);
    }
    return out;
}

// Applies one engine edit to the composed output the same way the hook
// pipeline does: delete `backspaces` characters, append the new text.
void apply_edit(std::u32string& composed, const SKeyEngineWrapper::Result& result) {
    for (int i = 0; i < result.backspaces && !composed.empty(); ++i) {
        composed.pop_back();
    }
    composed += to_codepoints(result.text);
}

struct Vector {
    const char* keys;
    const char* expected;
};

} // namespace

int main() {
    const Vector vectors[] = {
        {"dd", "\xc4\x91"},                             // đ
        {"ddasnh", "\xc4\x91\xC3\xA1nh"},               // đánh
        {"ker", "k\xE1\xBA\xBB"},                       // kẻ
        {"chayj", "ch\xE1\xBA\xA1y"},                   // chạy
        {"ddi", "\xc4\x91i"},                           // đi
        {"tieengs", "ti\xE1\xBA\xBFng"},                // tiếng
    };

    SKeyEngineWrapper engine;
    engine.set_input_method(InputMethod::telex);

    for (const auto& vector : vectors) {
        engine.reset();
        std::u32string composed;
        for (const char* key = vector.keys; *key != '\0'; ++key) {
            const char32_t ch = static_cast<char32_t>(static_cast<unsigned char>(*key));
            const auto result = engine.filter(ch);
            if (result.handled) apply_edit(composed, result);
            else composed.push_back(ch);
        }
        const std::u32string expected = to_codepoints(vector.expected);
        assert(composed == expected);
    }

    return 0;
}
