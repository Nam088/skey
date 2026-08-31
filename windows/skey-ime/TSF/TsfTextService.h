#pragma once

#ifdef _WIN32
#include <windows.h>
#include <msctf.h>

#include <memory>

namespace skey::windows {

class KeyEventSink;
class IKeyEventHandler;
class TsfTextHost;
class WindowsImeService;

class TsfTextService final : public ITfTextInputProcessor {
public:
    TsfTextService() noexcept = default;

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
    ULONG STDMETHODCALLTYPE AddRef() override;
    ULONG STDMETHODCALLTYPE Release() override;

    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr* thread_manager,
                                       TfClientId client_id) override;
    HRESULT STDMETHODCALLTYPE Deactivate() override;

    HRESULT AttachKeyEventSink(ITfContext* context) noexcept;

    bool active() const noexcept { return active_; }

private:
    ~TsfTextService() = default;
    void detach_sink() noexcept;

    LONG references_{1};
    ITfThreadMgr* thread_manager_{nullptr};
    TfClientId client_id_{TF_CLIENTID_NULL};
    bool active_{false};
    KeyEventSink* key_sink_{nullptr};
    ITfSource* advised_source_{nullptr};
    DWORD sink_cookie_{TF_INVALID_COOKIE};

    std::unique_ptr<TsfTextHost> text_host_;
    std::unique_ptr<WindowsImeService> service_;
};

} // namespace skey::windows
#endif
