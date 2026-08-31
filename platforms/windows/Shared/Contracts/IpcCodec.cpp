#include "IpcCodec.h"

#include <charconv>
#include <cctype>
#include <vector>

namespace skey::windows {
namespace {
std::string escape(std::string_view value) {
    std::string out;
    constexpr char hex[] = "0123456789ABCDEF";
    for (const unsigned char c : value) {
        if (std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') out += static_cast<char>(c);
        else { out += '%'; out += hex[c >> 4U]; out += hex[c & 0x0FU]; }
    }
    return out;
}
bool unescape(std::string_view value, std::string& out) {
    out.clear();
    for (std::size_t i = 0; i < value.size(); ++i) {
        if (value[i] != '%') { out += value[i]; continue; }
        if (i + 2 >= value.size() || !std::isxdigit(static_cast<unsigned char>(value[i + 1])) || !std::isxdigit(static_cast<unsigned char>(value[i + 2]))) return false;
        const auto digit = [](char c) { return c <= '9' ? c - '0' : (std::toupper(static_cast<unsigned char>(c)) - 'A' + 10); };
        out += static_cast<char>((digit(value[i + 1]) << 4) | digit(value[i + 2])); i += 2;
    }
    return true;
}
std::vector<std::string_view> split(std::string_view wire) {
    if (!wire.empty() && wire.back() == '\n') wire.remove_suffix(1);
    std::vector<std::string_view> fields; std::size_t start = 0;
    while (true) { const auto pos = wire.find('\t', start); fields.push_back(wire.substr(start, pos == std::string_view::npos ? pos : pos - start)); if (pos == std::string_view::npos) return fields; start = pos + 1; }
}
bool number(std::string_view s, std::uint32_t& value) { const auto result = std::from_chars(s.data(), s.data() + s.size(), value); return result.ec == std::errc{} && result.ptr == s.data() + s.size(); }
}

std::string IpcCodec::encode(const IpcRequest& r) { return "REQ\t" + std::to_string(r.protocol_version) + "\t" + escape(r.request_id) + "\t" + escape(r.method) + "\t" + std::to_string(r.deadline_ms) + "\t" + escape(r.payload) + "\n"; }
std::string IpcCodec::encode(const IpcResponse& r) { return "RES\t" + std::to_string(r.protocol_version) + "\t" + escape(r.request_id) + "\t" + (r.ok ? "1" : "0") + "\t" + escape(r.error_code) + "\t" + escape(r.payload) + "\n"; }
bool IpcCodec::decode_request(std::string_view wire, IpcRequest& r) { const auto f = split(wire); std::uint32_t version = 0, deadline = 0; return f.size() == 6 && f[0] == "REQ" && number(f[1], version) && number(f[4], deadline) && unescape(f[2], r.request_id) && unescape(f[3], r.method) && unescape(f[5], r.payload) && (r.protocol_version = version, r.deadline_ms = deadline, true); }
bool IpcCodec::decode_response(std::string_view wire, IpcResponse& r) { const auto f = split(wire); std::uint32_t version = 0; std::string ok; return f.size() == 6 && f[0] == "RES" && number(f[1], version) && unescape(f[2], r.request_id) && unescape(f[4], r.error_code) && unescape(f[5], r.payload) && (ok = std::string(f[3]), (ok == "0" || ok == "1")) && (r.protocol_version = version, r.ok = ok == "1", true); }
} // namespace skey::windows
