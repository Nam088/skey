// Stub implementations for Rust C API functions
// These are temporary stubs that allow the Windows build to succeed
// The real implementation requires building the Rust library

#ifdef _WIN32

#include <cstdint>

extern "C" {

struct SKeyEdit {
    int handled;
    int backspaces;
    const char* text;
    int committed;
    int reset;
};

void* skey_engine_create() { return nullptr; }
void skey_engine_free(void*) {}
void skey_engine_reset(void*) {}
void skey_engine_set_caps_state(void*, int, int) {}

SKeyEdit skey_engine_filter(void*, unsigned int) {
    return {0, 0, "", 0, 0};
}

SKeyEdit skey_engine_backspace(void*) {
    return {0, 0, "", 0, 0};
}

const char* skey_engine_output(void*) {
    return "";
}

} // extern "C"

#endif
