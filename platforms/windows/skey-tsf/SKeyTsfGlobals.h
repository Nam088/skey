#pragma once

#include <atomic>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

// Module handle + COM object lock count shared by the DLL translation units.
extern HMODULE g_skey_tsf_module;
extern std::atomic<long> g_skey_tsf_locks;
