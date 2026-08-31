#pragma once

#ifdef _WIN32
#include <windows.h>
#include <unknwn.h>

namespace skey::windows {

class ClassFactory final : public IClassFactory {
public:
    ClassFactory() noexcept = default;

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
    ULONG STDMETHODCALLTYPE AddRef() override;
    ULONG STDMETHODCALLTYPE Release() override;

    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID riid, void** object) override;
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override;

private:
    ~ClassFactory() = default;
    LONG references_{1};
};

} // namespace skey::windows
#endif
