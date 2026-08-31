#include "ClipboardText.h"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstring>

namespace skey::windows {

namespace {

struct FoldEntry {
    char32_t cp;
    char base;
};

// Diacritic/Vietnamese code point -> ASCII base letter (both cases).
const FoldEntry kFoldTable[] = {
    {0x00C0, 'a'}, {0x00C1, 'a'}, {0x00C2, 'a'}, {0x00C3, 'a'}, {0x00C4, 'a'},
    {0x00C5, 'a'}, {0x00C8, 'e'}, {0x00C9, 'e'}, {0x00CA, 'e'}, {0x00CB, 'e'},
    {0x00CC, 'i'}, {0x00CD, 'i'}, {0x00CE, 'i'}, {0x00CF, 'i'},
    {0x00D2, 'o'}, {0x00D3, 'o'}, {0x00D4, 'o'}, {0x00D5, 'o'}, {0x00D6, 'o'},
    {0x00D8, 'o'}, {0x00D9, 'u'}, {0x00DA, 'u'}, {0x00DB, 'u'}, {0x00DC, 'u'},
    {0x00DD, 'y'},
    {0x00E0, 'a'}, {0x00E1, 'a'}, {0x00E2, 'a'}, {0x00E3, 'a'}, {0x00E4, 'a'},
    {0x00E5, 'a'}, {0x00E8, 'e'}, {0x00E9, 'e'}, {0x00EA, 'e'}, {0x00EB, 'e'},
    {0x00EC, 'i'}, {0x00ED, 'i'}, {0x00EE, 'i'}, {0x00EF, 'i'},
    {0x00F2, 'o'}, {0x00F3, 'o'}, {0x00F4, 'o'}, {0x00F5, 'o'}, {0x00F6, 'o'},
    {0x00F8, 'o'}, {0x00F9, 'u'}, {0x00FA, 'u'}, {0x00FB, 'u'}, {0x00FC, 'u'},
    {0x00FD, 'y'}, {0x00FF, 'y'},
    {0x0100, 'a'}, {0x0101, 'a'}, {0x0102, 'a'}, {0x0103, 'a'}, {0x0104, 'a'},
    {0x0105, 'a'}, {0x0110, 'd'}, {0x0111, 'd'},
    {0x0112, 'e'}, {0x0113, 'e'}, {0x0114, 'e'}, {0x0115, 'e'}, {0x0116, 'e'},
    {0x0117, 'e'}, {0x0118, 'e'}, {0x0119, 'e'}, {0x011A, 'e'}, {0x011B, 'e'},
    {0x0128, 'i'}, {0x0129, 'i'}, {0x012A, 'i'}, {0x012B, 'i'}, {0x012C, 'i'},
    {0x012D, 'i'}, {0x012E, 'i'}, {0x012F, 'i'},
    {0x014C, 'o'}, {0x014D, 'o'}, {0x014E, 'o'}, {0x014F, 'o'}, {0x0150, 'o'},
    {0x0151, 'o'}, {0x0168, 'u'}, {0x0169, 'u'}, {0x016A, 'u'}, {0x016B, 'u'},
    {0x016C, 'u'}, {0x016D, 'u'}, {0x016E, 'u'}, {0x016F, 'u'}, {0x0170, 'u'},
    {0x0171, 'u'},
    {0x01A0, 'o'}, {0x01A1, 'o'}, {0x01AF, 'u'}, {0x01B0, 'u'},
    {0x1EA0, 'a'}, {0x1EA1, 'a'}, {0x1EA2, 'a'}, {0x1EA3, 'a'}, {0x1EA4, 'a'},
    {0x1EA5, 'a'}, {0x1EA6, 'a'}, {0x1EA7, 'a'}, {0x1EA8, 'a'}, {0x1EA9, 'a'},
    {0x1EAA, 'a'}, {0x1EAB, 'a'}, {0x1EAC, 'a'}, {0x1EAD, 'a'}, {0x1EAE, 'a'},
    {0x1EAF, 'a'}, {0x1EB0, 'a'}, {0x1EB1, 'a'}, {0x1EB2, 'a'}, {0x1EB3, 'a'},
    {0x1EB4, 'a'}, {0x1EB5, 'a'}, {0x1EB6, 'a'}, {0x1EB7, 'a'},
    {0x1EB8, 'e'}, {0x1EB9, 'e'}, {0x1EBA, 'e'}, {0x1EBB, 'e'}, {0x1EBC, 'e'},
    {0x1EBD, 'e'}, {0x1EBE, 'e'}, {0x1EBF, 'e'}, {0x1EC0, 'e'}, {0x1EC1, 'e'},
    {0x1EC2, 'e'}, {0x1EC3, 'e'}, {0x1EC4, 'e'}, {0x1EC5, 'e'}, {0x1EC6, 'e'},
    {0x1EC7, 'e'}, {0x1EC8, 'i'}, {0x1EC9, 'i'}, {0x1ECA, 'i'}, {0x1ECB, 'i'},
    {0x1ECC, 'o'}, {0x1ECD, 'o'}, {0x1ECE, 'o'}, {0x1ECF, 'o'}, {0x1ED0, 'o'},
    {0x1ED1, 'o'}, {0x1ED2, 'o'}, {0x1ED3, 'o'}, {0x1ED4, 'o'}, {0x1ED5, 'o'},
    {0x1ED6, 'o'}, {0x1ED7, 'o'}, {0x1ED8, 'o'}, {0x1ED9, 'o'}, {0x1EDA, 'o'},
    {0x1EDB, 'o'}, {0x1EDC, 'o'}, {0x1EDD, 'o'}, {0x1EDE, 'o'}, {0x1EDF, 'o'},
    {0x1EE0, 'o'}, {0x1EE1, 'o'}, {0x1EE2, 'o'}, {0x1EE3, 'o'},
    {0x1EE4, 'u'}, {0x1EE5, 'u'}, {0x1EE6, 'u'}, {0x1EE7, 'u'}, {0x1EE8, 'u'},
    {0x1EE9, 'u'}, {0x1EEA, 'u'}, {0x1EEB, 'u'}, {0x1EEC, 'u'}, {0x1EED, 'u'},
    {0x1EEE, 'u'}, {0x1EEF, 'u'}, {0x1EF0, 'u'}, {0x1EF1, 'u'},
    {0x1EF4, 'y'}, {0x1EF5, 'y'}, {0x1EF6, 'y'}, {0x1EF7, 'y'}, {0x1EF8, 'y'},
    {0x1EF9, 'y'},
};

char fold_code_point(char32_t cp) {
    if (cp < 0x80) {
        if (cp >= 'A' && cp <= 'Z') return static_cast<char>(cp - 'A' + 'a');
        return static_cast<char>(cp);
    }
    const auto* begin = std::begin(kFoldTable);
    const auto* end = std::end(kFoldTable);
    const auto* it = std::lower_bound(
        begin, end, cp, [](const FoldEntry& e, char32_t v) { return e.cp < v; });
    if (it != end && it->cp == cp) return it->base;
    return '\0';
}

void append_utf8(std::string& out, char32_t cp) {
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xF0 | (cp >> 18));
        out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
}

bool is_folded_subsequence(const std::string& folded_text, const std::string& folded_query) {
    std::size_t qi = 0;
    for (std::size_t ti = 0; ti < folded_text.size() && qi < folded_query.size(); ++ti) {
        if (folded_text[ti] == folded_query[qi]) ++qi;
    }
    return qi == folded_query.size();
}

// --- SHA-256 (FIPS 180-4) ---

constexpr std::array<std::uint32_t, 64> kK = {{
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2}};

std::uint32_t rotr(std::uint32_t x, unsigned n) { return (x >> n) | (x << (32 - n)); }

} // namespace

std::string ClipboardText::fold(const std::string& utf8) {
    std::string out;
    out.reserve(utf8.size());
    std::size_t i = 0;
    while (i < utf8.size()) {
        const auto b0 = static_cast<unsigned char>(utf8[i]);
        char32_t cp = 0;
        int extra = 0;
        if (b0 < 0x80) { cp = b0; }
        else if ((b0 & 0xE0) == 0xC0) { cp = b0 & 0x1F; extra = 1; }
        else if ((b0 & 0xF0) == 0xE0) { cp = b0 & 0x0F; extra = 2; }
        else if ((b0 & 0xF8) == 0xF0) { cp = b0 & 0x07; extra = 3; }
        else { ++i; continue; }

        if (extra > 0 && i + extra >= utf8.size()) break;
        bool valid = true;
        for (int k = 1; k <= extra; ++k) {
            const auto b = static_cast<unsigned char>(utf8[i + k]);
            if ((b & 0xC0) != 0x80) { valid = false; break; }
            cp = (cp << 6) | (b & 0x3F);
        }
        i += extra + 1;
        if (!valid) continue;

        if (cp < 0x80) {
            out += (cp >= 'A' && cp <= 'Z') ? static_cast<char>(cp - 'A' + 'a') : static_cast<char>(cp);
            continue;
        }
        const char base = fold_code_point(cp);
        if (base != '\0') out += base;
        else append_utf8(out, cp);
    }
    return out;
}

long long ClipboardText::rank(const std::string& text,
                              const std::string& folded_text,
                              const std::string& query) {
    if (query.empty()) return 2000000;
    const auto exact = text.find(query);
    if (exact != std::string::npos) {
        return 2000000 - static_cast<long long>(std::min(exact, static_cast<std::size_t>(2000000)));
    }
    const auto folded_query = fold(query);
    if (folded_query.empty()) return -1;
    const auto folded_at = folded_text.find(folded_query);
    if (folded_at != std::string::npos) {
        return 1000000 - static_cast<long long>(std::min(folded_at, static_cast<std::size_t>(1000000)));
    }
    if (is_folded_subsequence(folded_text, folded_query)) return 0;
    return -1;
}

std::string ClipboardText::sha256_hex(const std::string& data) {
    std::uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                          0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

    std::string msg = data;
    const std::uint64_t bit_len = static_cast<std::uint64_t>(data.size()) * 8;
    msg += static_cast<char>(0x80);
    while (msg.size() % 64 != 56) msg += '\0';
    for (int i = 7; i >= 0; --i) msg += static_cast<char>((bit_len >> (i * 8)) & 0xFF);

    std::uint32_t w[64];
    for (std::size_t block = 0; block < msg.size(); block += 64) {
        for (int t = 0; t < 16; ++t) {
            w[t] = (static_cast<std::uint32_t>(static_cast<unsigned char>(msg[block + t * 4])) << 24) |
                   (static_cast<std::uint32_t>(static_cast<unsigned char>(msg[block + t * 4 + 1])) << 16) |
                   (static_cast<std::uint32_t>(static_cast<unsigned char>(msg[block + t * 4 + 2])) << 8) |
                   static_cast<std::uint32_t>(static_cast<unsigned char>(msg[block + t * 4 + 3]));
        }
        for (int t = 16; t < 64; ++t) {
            const std::uint32_t s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            const std::uint32_t s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16] + s0 + w[t - 7] + s1;
        }
        std::uint32_t a = h[0], b = h[1], c = h[2], d = h[3];
        std::uint32_t e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int t = 0; t < 64; ++t) {
            const std::uint32_t s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            const std::uint32_t ch = (e & f) ^ (~e & g);
            const std::uint32_t temp1 = hh + s1 + ch + kK[t] + w[t];
            const std::uint32_t s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            const std::uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
            const std::uint32_t temp2 = s0 + maj;
            hh = g; g = f; f = e; e = d + temp1;
            d = c; c = b; b = a; a = temp1 + temp2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d;
        h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }

    static const char* hex = "0123456789abcdef";
    std::string out;
    out.reserve(64);
    for (std::uint32_t v : h) {
        for (int i = 3; i >= 0; --i) {
            const auto byte = (v >> (i * 8)) & 0xFF;
            out += hex[byte >> 4];
            out += hex[byte & 0xF];
        }
    }
    return out;
}

bool ClipboardText::is_blank(const std::string& utf8) {
    for (const char c : utf8) {
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r') return false;
    }
    return true;
}

} // namespace skey::windows
