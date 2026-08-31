#include "TsfBridge.h"

#include <cstring>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <sddl.h>
#endif

namespace skey::windows {

namespace tsf_bridge {

std::wstring to_wide(const std::string& utf8) {
    std::wstring out;
    out.reserve(utf8.size());
    std::size_t i = 0;
    while (i < utf8.size()) {
        const auto b0 = static_cast<unsigned char>(utf8[i]);
        unsigned int cp = 0;
        std::size_t len = 1;
        if (b0 < 0x80) {
            cp = b0;
        } else if ((b0 & 0xE0) == 0xC0 && i + 1 < utf8.size()) {
            cp = (static_cast<unsigned int>(b0 & 0x1Fu) << 6) |
                 (static_cast<unsigned char>(utf8[i + 1]) & 0x3Fu);
            len = 2;
        } else if ((b0 & 0xF0) == 0xE0 && i + 2 < utf8.size()) {
            cp = (static_cast<unsigned int>(b0 & 0x0Fu) << 12) |
                 ((static_cast<unsigned char>(utf8[i + 1]) & 0x3Fu) << 6) |
                 (static_cast<unsigned char>(utf8[i + 2]) & 0x3Fu);
            len = 3;
        } else if ((b0 & 0xF8) == 0xF0 && i + 3 < utf8.size()) {
            cp = (static_cast<unsigned int>(b0 & 0x07u) << 18) |
                 ((static_cast<unsigned char>(utf8[i + 1]) & 0x3Fu) << 12) |
                 ((static_cast<unsigned char>(utf8[i + 2]) & 0x3Fu) << 6) |
                 (static_cast<unsigned char>(utf8[i + 3]) & 0x3Fu);
            len = 4;
        }
        if (len == 1 && b0 >= 0x80) {
            out.push_back(static_cast<wchar_t>(0xFFFD));
        } else if (cp >= 0x10000) {
            cp -= 0x10000;
            out.push_back(static_cast<wchar_t>(0xD800 + (cp >> 10)));
            out.push_back(static_cast<wchar_t>(0xDC00 + (cp & 0x3FF)));
        } else {
            out.push_back(static_cast<wchar_t>(cp));
        }
        i += len;
    }
    return out;
}

std::string to_utf8(const std::wstring& wide) {
    std::string out;
    out.reserve(wide.size() * 2);
    for (std::size_t i = 0; i < wide.size(); ++i) {
        unsigned int cp = static_cast<unsigned int>(static_cast<std::uint16_t>(wide[i]));
        if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < wide.size()) {
            const unsigned int lo = static_cast<unsigned int>(static_cast<std::uint16_t>(wide[i + 1]));
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                ++i;
            }
        }
        if (cp < 0x80) {
            out.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp < 0x10000) {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    return out;
}

bool encode_push(TsfBridgeFrame& frame, std::uint32_t seq, std::uint32_t target_pid,
                 int backspaces, const std::string& utf8) {
    const std::wstring wide = to_wide(utf8);
    if (wide.size() > kTsfMaxTextUnits) return false;
    std::memset(&frame, 0, sizeof(frame));
    frame.magic = kTsfBridgeMagic;
    frame.version = kTsfBridgeVersion;
    frame.seq = seq;
    frame.type = static_cast<std::uint32_t>(TsfBridgeMsg::push);
    frame.target_pid = target_pid;
    frame.backspaces = static_cast<std::int32_t>(backspaces);
    frame.text_len = static_cast<std::uint32_t>(wide.size());
    std::memcpy(frame.text, wide.data(), wide.size() * sizeof(wchar_t));
    return true;
}

bool decode_push(const TsfBridgeFrame& frame, std::uint32_t expected_seq,
                 std::uint32_t expected_pid, int& backspaces, std::string& out_utf8) {
    if (frame.magic != kTsfBridgeMagic || frame.version != kTsfBridgeVersion) return false;
    if (frame.type != static_cast<std::uint32_t>(TsfBridgeMsg::push)) return false;
    if (expected_seq != 0 && frame.seq != expected_seq) return false;
    if (expected_pid != 0 && frame.target_pid != expected_pid) return false;
    if (frame.text_len > kTsfMaxTextUnits) return false;
    backspaces = frame.backspaces;
    out_utf8 = to_utf8(std::wstring(frame.text, frame.text_len));
    return true;
}

} // namespace tsf_bridge

#ifdef _WIN32

namespace {

// Medium-integrity browsers must be able to open the objects the tray creates.
SECURITY_ATTRIBUTES* permissive_attributes() {
    static SECURITY_ATTRIBUTES sa = [] {
        SECURITY_ATTRIBUTES attrs{};
        attrs.nLength = sizeof(attrs);
        PSECURITY_DESCRIPTOR sd = nullptr;
        if (ConvertStringSecurityDescriptorToSecurityDescriptorW(
                L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;AU)", SDDL_REVISION_1, &sd, nullptr)) {
            attrs.lpSecurityDescriptor = sd;  // leaked once on purpose (process lifetime)
        }
        return attrs;
    }();
    return &sa;
}

std::uint64_t steady_now_ms() {
    LARGE_INTEGER freq;
    LARGE_INTEGER count;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&count);
    if (freq.QuadPart == 0) return 0;
    return static_cast<std::uint64_t>(count.QuadPart * 1000 / freq.QuadPart);
}

} // namespace

TsfBridgeClient::~TsfBridgeClient() { close(); }

bool TsfBridgeClient::open() {
    if (view_ != nullptr) return true;

    SECURITY_ATTRIBUTES* sa = permissive_attributes();
    section_ = CreateFileMappingW(INVALID_HANDLE_VALUE, sa, PAGE_READWRITE, 0,
                                  static_cast<DWORD>(sizeof(TsfBridgeFrame)),
                                  kTsfSharedMemName);
    if (section_ == nullptr) return false;
    view_ = MapViewOfFile(section_, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(TsfBridgeFrame));
    if (view_ == nullptr) {
        CloseHandle(section_);
        section_ = nullptr;
        return false;
    }
    std::memset(view_, 0, sizeof(TsfBridgeFrame));

    mutex_ = CreateMutexW(sa, FALSE, kTsfMutexName);
    response_event_ = CreateEventW(sa, FALSE, FALSE, kTsfResponseEventName);
    if (mutex_ == nullptr || response_event_ == nullptr) {
        close();
        return false;
    }
    return true;
}

void TsfBridgeClient::close() {
    if (view_ != nullptr) UnmapViewOfFile(view_);
    if (section_ != nullptr) CloseHandle(section_);
    if (mutex_ != nullptr) CloseHandle(mutex_);
    if (response_event_ != nullptr) CloseHandle(response_event_);
    view_ = nullptr;
    section_ = nullptr;
    mutex_ = nullptr;
    response_event_ = nullptr;
}

bool TsfBridgeClient::push_failed() {
    if (++failure_streak_ >= 2) {
        cooldown_until_ms_ = steady_now_ms() + 2000;
    }
    return false;
}

bool TsfBridgeClient::push(std::uint32_t target_pid, int backspaces, const std::string& utf8) {
    if (view_ == nullptr || target_pid == 0) return false;
    const std::uint64_t now = steady_now_ms();
    if (now < cooldown_until_ms_) return false;

    wchar_t event_name[64];
    swprintf_s(event_name, L"%s%lu", kTsfRequestEventPrefix, static_cast<unsigned long>(target_pid));
    HANDLE request_event = OpenEventW(EVENT_MODIFY_STATE, FALSE, event_name);
    if (request_event == nullptr) {
        // The TSF DLL is not loaded in the foreground process.
        return push_failed();
    }

    const DWORD mutex_rc = WaitForSingleObject(mutex_, static_cast<DWORD>(kPushMutexWaitMs));
    if (mutex_rc != WAIT_OBJECT_0 && mutex_rc != WAIT_ABANDONED) {
        CloseHandle(request_event);
        return push_failed();
    }

    auto* frame = static_cast<TsfBridgeFrame*>(view_);
    const std::uint32_t seq = ++seq_;
    const bool encoded = tsf_bridge::encode_push(*frame, seq, target_pid, backspaces, utf8);
    ReleaseMutex(mutex_);
    if (!encoded) {
        CloseHandle(request_event);
        return push_failed();
    }

    ResetEvent(response_event_);
    SetEvent(request_event);
    CloseHandle(request_event);

    if (WaitForSingleObject(response_event_, static_cast<DWORD>(kPushReplyWaitMs)) != WAIT_OBJECT_0) {
        return push_failed();
    }
    if (frame->type != static_cast<std::uint32_t>(TsfBridgeMsg::response) ||
        frame->seq != seq || frame->status != 0) {
        return push_failed();
    }
    failure_streak_ = 0;
    return true;
}

#endif // _WIN32

} // namespace skey::windows
