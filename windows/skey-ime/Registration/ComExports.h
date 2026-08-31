#pragma once

#ifdef _WIN32
#include <windows.h>

extern "C" {
STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** object);
STDAPI DllCanUnloadNow();
STDAPI DllRegisterServer();
STDAPI DllUnregisterServer();
}

#endif
