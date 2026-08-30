#ifdef _WIN32
#include <windows.h>

#include "TrayIpcHandler.h"

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    using namespace skey::windows;
    TrayRuntime runtime;
    TrayIpcHandler handler(runtime);
    if (!runtime.start_ipc(handler)) return 1;
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    runtime.stop();
    return 0;
}
#endif
