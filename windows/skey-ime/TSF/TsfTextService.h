#pragma once

#ifdef _WIN32
#include <windows.h>
#include <msctf.h>

namespace skey::windows {

class KeyEventSink;
class IKeyEventHandler;

// Minimal in-process TSF text service.  The implementation deliberately keeps
// platform plumbing separate from the portable engine/composition host.
class TsfTextService final : public ITfTextInputProcessor {
public:
    TsfTextService() noexcept = default;

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
    ULONG STDMETHODCALLTYPE AddRef() override;
    ULONG STDMETHODCALLTYPE Release() override;

    // ITfTextInputProcessor
    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr* thread_manager,
                                       TfClientId client_id) override;
    HRESULT STDMETHODCALLTYPE Deactivate() override;

    // Hosts call this when a focused context becomes available. The sink is
    // advised through TSF and detached automatically on Deactivate().
    HRESULT AttachKeyEventSink(ITfContext* context, IKeyEventHandler* handler = nullptr) noexcept;

    bool active() const noexcept { return active_; }

private:
    ~TsfTextService() = default;
    LONG references_{1};
    ITfThreadMgr* thread_manager_{nullptr};
    TfClientId client_id_{TF_CLIENTID_NULL};
    bool active_{false};
    KeyEventSink* key_sink_{nullptr};
    ITfSource* advised_source_{nullptr};
    DWORD sink_cookie_{TF_INVALID_COOKIE};
};

} // namespace skey::windows
#endif
