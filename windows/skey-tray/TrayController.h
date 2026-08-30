#pragma once

#include "../Shared/Contracts/IpcProtocol.h"

namespace skey::windows {

class TrayController final {
public:
    bool start();
    void stop();
    bool is_running() const { return running_; }

private:
    bool running_{false};
};

} // namespace skey::windows
