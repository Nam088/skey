#pragma once

#include <cstdint>
#include <string>

namespace skey::windows {

// Phase 5: bridge between skey-tray.exe and skey-tsf.dll (a minimal TSF text
// service loaded inside browser processes). Chromium omniboxes mishandle the
// SendInput backspace+re-inject sequence the hook pipeline normally uses, so
// when the foreground app is a browser the engine result is pushed through
// this channel and applied as a TSF edit session inside the app itself
// (same architecture EVKey uses with EVKeyIME_SharedMem_v1).
//
// Topology:
//   EXE owns the section/mutex/response event. Each browser process that
//   loads skey-tsf.dll creates its own request event named
//   SKeyTsf_Req_<pid>; the EXE signals the event of the foreground process
//   only. If the event does not exist (DLL not loaded there), push() fails
//   fast and the pipeline falls back to SendInput injection.

inline constexpr const wchar_t* kTsfSharedMemName = L"SKeyTsf_SharedMem_v1";
inline constexpr const wchar_t* kTsfResponseEventName = L"SKeyTsf_Response_v1";
inline constexpr const wchar_t* kTsfMutexName = L"SKeyTsf_Mutex_v1";
// Prefix of the per-process request event created by the DLL.
inline constexpr const wchar_t* kTsfRequestEventPrefix = L"SKeyTsf_Req_";

// Identity of skey-tsf.dll. The DLL defines the same GUIDs; the EXE needs
// the text form to build the TIP layout name for LoadKeyboardLayoutW.
inline constexpr const wchar_t* kSKeyTsfClsid = L"{7E5F3A2C-61B4-4D8E-9C37-2A5B8D40F6E1}";
inline constexpr const wchar_t* kSKeyTsfProfile = L"{4B9C1D7E-8F2A-4E63-B5D0-9C7A3E1F2B48}";
inline constexpr const wchar_t* kSKeyTsfLayoutName =
    L"{7E5F3A2C-61B4-4D8E-9C37-2A5B8D40F6E1}{4B9C1D7E-8F2A-4E63-B5D0-9C7A3E1F2B48}";

inline constexpr std::uint32_t kTsfBridgeMagic = 0x534B5446u;  // 'SKTF'
inline constexpr std::uint32_t kTsfBridgeVersion = 1u;
inline constexpr std::size_t kTsfMaxTextUnits = 96;

enum class TsfBridgeMsg : std::uint32_t {
    idle = 0,
    push = 1,      // EXE -> DLL: apply {backspaces, text} at the caret
    response = 2,  // DLL -> EXE: status of the last push
};

// Fixed-size frame living in the shared memory section. Plain layout, no
// pointers; both sides run on x64 Windows so endianness/packing match.
struct TsfBridgeFrame {
    std::uint32_t magic;
    std::uint32_t version;
    std::uint32_t seq;         // request id echoed by the response
    std::uint32_t type;        // TsfBridgeMsg
    std::uint32_t target_pid;  // foreground process the push is meant for
    std::int32_t backspaces;   // chars before the caret to replace
    std::uint32_t text_len;    // UTF-16 units in `text`
    std::uint32_t status;      // response only: 0 = applied
    wchar_t text[kTsfMaxTextUnits];
};

// Platform-independent frame helpers (unit-tested on all hosts).
namespace tsf_bridge {

// Serializes a push request. Returns false when the text does not fit.
bool encode_push(TsfBridgeFrame& frame, std::uint32_t seq, std::uint32_t target_pid,
                 int backspaces, const std::string& utf8);

// Validates + deserializes a push request. `out_utf8` receives UTF-8.
bool decode_push(const TsfBridgeFrame& frame, std::uint32_t expected_seq,
                 std::uint32_t expected_pid, int& backspaces, std::string& out_utf8);

// Local converters (kept here so Shared/ never depends on skey-tray).
std::wstring to_wide(const std::string& utf8);
std::string to_utf8(const std::wstring& wide);

} // namespace tsf_bridge

#ifdef _WIN32

// EXE-side client. push() round-trips one frame to the skey-tsf.dll loaded
// in `target_pid` and returns true when the DLL applied the edit. On any
// timeout/absence it returns false so the caller falls back to SendInput.
// Called from the hook thread: bounded by kPushMutexWaitMs + kPushReplyWaitMs.
class TsfBridgeClient {
public:
    TsfBridgeClient() = default;
    ~TsfBridgeClient();
    TsfBridgeClient(const TsfBridgeClient&) = delete;
    TsfBridgeClient& operator=(const TsfBridgeClient&) = delete;

    bool open();
    void close();
    bool opened() const { return view_ != nullptr; }

    bool push(std::uint32_t target_pid, int backspaces, const std::string& utf8);

    static constexpr unsigned long kPushMutexWaitMs = 5;
    static constexpr unsigned long kPushReplyWaitMs = 8;

private:
    bool push_failed();

    void* section_ = nullptr;
    void* view_ = nullptr;
    void* response_event_ = nullptr;
    void* mutex_ = nullptr;
    std::uint32_t seq_ = 0;
    int failure_streak_ = 0;
    std::uint64_t cooldown_until_ms_ = 0;
};

#endif // _WIN32

} // namespace skey::windows
