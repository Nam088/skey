#ifdef _WIN32
#include "WindowsKeyPipeline.h"
namespace skey::windows {
bool WindowsKeyPipeline::test(const KeyEvent& event) noexcept { return event.kind == EventKind::key_down || event.kind == EventKind::backspace; }
bool WindowsKeyPipeline::handle(const KeyEvent& event) noexcept { return host_.dispatch(event).handled; }
void WindowsKeyPipeline::focus_changed() noexcept { host_.dispatch(KeyEvent{.kind = EventKind::focus_changed}); }
}
#endif
