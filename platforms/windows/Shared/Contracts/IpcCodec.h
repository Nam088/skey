#pragma once

#include "IpcProtocol.h"

#include <string>
#include <string_view>

namespace skey::windows {

// A dependency-free, line framed wire format. Fields are percent encoded so
// payloads may contain newlines, tabs, and arbitrary UTF-8 text.
class IpcCodec final {
public:
    static std::string encode(const IpcRequest& request);
    static std::string encode(const IpcResponse& response);
    static bool decode_request(std::string_view wire, IpcRequest& request);
    static bool decode_response(std::string_view wire, IpcResponse& response);
};

} // namespace skey::windows
