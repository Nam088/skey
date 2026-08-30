#pragma once

#include "IEngine.h"
#include <skey.h>

#include <memory>

namespace skey::windows {

class CoreEngineAdapter final : public IEngine {
public:
    CoreEngineAdapter();
    ~CoreEngineAdapter() override;

    CoreEngineAdapter(const CoreEngineAdapter&) = delete;
    CoreEngineAdapter& operator=(const CoreEngineAdapter&) = delete;

    EditResult filter(std::uint32_t codepoint) override;
    EditResult backspace() override;
    void reset() override;

private:
    EditResult read_edit(::SKeyEdit edit);
    ::SKeyEngine* engine_{nullptr};
};

} // namespace skey::windows
