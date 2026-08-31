// Minimal skey.lib link smoke test: localizes whether the Rust staticlib
// hangs at process startup, engine creation, or the first filter call.
#include "../skey-tray/Engine/SKeyEngineWrapper.h"

#include <cstdio>

using namespace skey::windows;

int main() {
    std::fprintf(stderr, "SMOKE main enter\n");
    SKeyEngineWrapper engine;
    std::fprintf(stderr, "SMOKE engine created\n");
    engine.set_input_method(EngineInputMethod::telex);
    const auto result = engine.filter(U'd');
    std::fprintf(stderr, "SMOKE filter done handled=%d\n", result.handled ? 1 : 0);
    return 0;
}
