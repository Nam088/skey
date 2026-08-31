#include "TrayController.h"

namespace skey::windows {

bool TrayController::start() {
    running_ = true;
    return running_;
}

void TrayController::stop() { running_ = false; }

} // namespace skey::windows
