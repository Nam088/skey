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
    // Blocks until one request is served. `alive` is polled while waiting for
    // a client so the server thread can be joined on shutdown; when it turns
    // false the pending accept is cancelled and false is returned.
    bool serve_once(const std::string& endpoint = kIpcPipeName,
                    const std::function<bool()>& alive = nullptr) const;
private:
    IpcHandler handler_;
};

} // namespace skey::windows
