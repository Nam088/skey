#pragma once

#include <unknwn.h>

#include "SKeyTsfGlobals.h"

class CClassFactory final : public IClassFactory {
public:
    CClassFactory() = default;

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** object) override {
        if (object == nullptr) return E_POINTER;
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *object = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        *object = nullptr;
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG) AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&refs_));
    }
    STDMETHODIMP_(ULONG) Release() override {
        const long remaining = InterlockedDecrement(&refs_);
        if (remaining == 0) delete this;
        return static_cast<ULONG>(remaining);
    }

    // IClassFactory
    STDMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** object) override;
    STDMETHODIMP LockServer(BOOL lock) override {
        if (lock) {
            g_skey_tsf_locks.fetch_add(1);
        } else {
            g_skey_tsf_locks.fetch_sub(1);
        }
        return S_OK;
    }

private:
    long refs_{1};
};
