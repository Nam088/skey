#pragma once

#include <cstdint>
#include <string>

namespace skey::windows {

inline constexpr std::uint32_t kIpcProtocolVersion = 1;

struct IpcRequest final {
    std::uint32_t protocol_version{kIpcProtocolVersion};
    std::string request_id;
    std::string method;
    std::string payload;
    std::uint32_t deadline_ms{3000};
};

struct IpcResponse final {
    std::uint32_t protocol_version{kIpcProtocolVersion};
    std::string request_id;
    bool ok{false};
    std::string error_code;
    std::string payload;
};

inline constexpr char kGetStatus[] = "getStatus";
inline constexpr char kSetLanguage[] = "setLanguage";
inline constexpr char kSetInputMethod[] = "setInputMethod";
inline constexpr char kResetEngine[] = "resetEngine";
inline constexpr char kGetSettings[] = "getSettings";
inline constexpr char kSetSettings[] = "setSettings";
inline constexpr char kRestartService[] = "restartService";

} // namespace skey::windows
