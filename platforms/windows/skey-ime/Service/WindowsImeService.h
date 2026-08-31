#pragma once
#ifdef _WIN32
#include "../Engine/CoreEngineAdapter.h"
#include "../EventHandling/Pipeline/WindowsKeyPipeline.h"
namespace skey::windows {
class WindowsImeService final {
public:
    explicit WindowsImeService(ITextHost& host) : engine_(), composition_(engine_, host), pipeline_(composition_) {}
    IKeyEventHandler& key_handler() noexcept { return pipeline_; }
    void reset() noexcept { composition_.dispatch(KeyEvent{.kind = EventKind::reset}); }
private:
    CoreEngineAdapter engine_;
    CompositionHost composition_;
    WindowsKeyPipeline pipeline_;
};
}
#endif
