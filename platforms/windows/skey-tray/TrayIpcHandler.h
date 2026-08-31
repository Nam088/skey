#pragma once
#include "../Shared/Contracts/IpcProtocol.h"
#include "TrayRuntime.h"
namespace skey::windows {
class TrayIpcHandler final {
public:
    explicit TrayIpcHandler(TrayRuntime& runtime) noexcept : runtime_(runtime) {}
    IpcResponse operator()(const IpcRequest& request) const;
private:
    TrayRuntime& runtime_;
};
}
