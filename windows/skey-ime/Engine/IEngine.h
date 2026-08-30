#pragma once

#include "../Models/InputContracts.h"

namespace skey::windows {

class IEngine {
public:
    virtual ~IEngine() = default;
    virtual EditResult filter(std::uint32_t codepoint) = 0;
    virtual EditResult backspace() = 0;
    virtual void reset() = 0;
};

} // namespace skey::windows
