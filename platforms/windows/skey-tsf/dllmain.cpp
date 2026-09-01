#include "SKeyTsfGlobals.h"

HMODULE g_skey_tsf_module = nullptr;
std::atomic<long> g_skey_tsf_locks{0};

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_skey_tsf_module = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}
