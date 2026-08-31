#ifdef _WIN32
#include <windows.h>
#include <atomic>

HINSTANCE g_hInstance = nullptr;
std::atomic<LONG> g_moduleRef{0};

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        g_hInstance = module;
        DisableThreadLibraryCalls(module);
        break;
    case DLL_PROCESS_DETACH:
        g_hInstance = nullptr;
        break;
    }
    return TRUE;
}

#endif
