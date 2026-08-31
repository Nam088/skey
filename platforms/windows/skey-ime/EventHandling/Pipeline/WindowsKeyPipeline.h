#pragma once
#ifdef _WIN32
#include "../../Host/CompositionHost.h"
#include "../../TSF/IKeyEventHandler.h"
namespace skey::windows {
class WindowsKeyPipeline final : public IKeyEventHandler {
public:
    explicit WindowsKeyPipeline(CompositionHost& host) noexcept : host_(host) {}
    bool test(const KeyEvent& event) noexcept override;
    bool handle(const KeyEvent& event) noexcept override;
    void focus_changed() noexcept override;
private:
    CompositionHost& host_;
};
}
#endif
