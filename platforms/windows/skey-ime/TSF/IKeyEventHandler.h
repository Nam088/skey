#pragma once

#ifdef _WIN32
#include "../Models/InputContracts.h"

namespace skey::windows {

class IKeyEventHandler {
public:
    virtual ~IKeyEventHandler() = default;
    virtual bool test(const KeyEvent& event) noexcept = 0;
    virtual bool handle(const KeyEvent& event) noexcept = 0;
    virtual void focus_changed() noexcept = 0;
};

} // namespace skey::windows
#endif
