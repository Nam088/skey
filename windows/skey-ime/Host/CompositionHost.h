#pragma once

#include "ITextHost.h"
#include "../Engine/IEngine.h"

namespace skey::windows {

class CompositionHost final {
public:
    CompositionHost(IEngine& engine, ITextHost& host) : engine_(engine), host_(host) {}

    EditResult dispatch(const KeyEvent& event);

private:
    EditResult apply_edit(EditResult result);
    void reset();

    IEngine& engine_;
    ITextHost& host_;
};

} // namespace skey::windows
