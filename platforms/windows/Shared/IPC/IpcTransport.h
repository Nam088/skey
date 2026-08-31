#pragma once

#include "../Contracts/IpcCodec.h"
#include <functional>
#include <string>

namespace skey::windows {

inline constexpr char kIpcPipeName[] = "\\\\.\\pipe\\SKey.InputService.v1";
using IpcHandler = std::function<IpcResponse(const IpcRequest&)>;

class IpcClient final {
public:
    explicit IpcClient(std::string endpoint = kIpcPipeName);
    bool call(const IpcRequest& request, IpcResponse& response) const;
private:
    std::string endpoint_;
};

class IpcServer final {
public:
    explicit IpcServer(IpcHandler handler);
    bool serve_once(const std::string& endpoint = kIpcPipeName) const;
private:
    IpcHandler handler_;
};

} // namespace skey::windows
