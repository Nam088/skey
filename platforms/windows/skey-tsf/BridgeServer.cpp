#include "BridgeServer.h"

#include <cstdio>
#include <cstring>

namespace skey::tsf {

std::atomic<int> BridgeServer::refs_{0};
std::atomic<HWND> BridgeServer::window_{nullptr};
std::atomic<bool> BridgeServer::running_{false};
std::thread BridgeServer::thread_;

void BridgeServer::attach(HWND service_window) {
    window_.store(service_window);
    if (refs_.fetch_add(1) == 0) {
        running_.store(true);
        thread_ = std::thread(worker);
    }
}

void BridgeServer::detach() {
    if (refs_.fetch_sub(1) <= 1) {
        running_.store(false);
        // The worker may be mid-SendMessageTimeout to this process's UI
        // thread; the bounded timeout keeps the join from hanging.
        if (thread_.joinable()) thread_.join();
        window_.store(nullptr);
    }
}

void BridgeServer::worker() {
    wchar_t request_name[64];
    swprintf_s(request_name, L"%s%lu", kTsfRequestEventPrefix,
               static_cast<unsigned long>(GetCurrentProcessId()));
    HANDLE request = CreateEventW(nullptr, FALSE, FALSE, request_name);

    HANDLE section = nullptr;
    void* view = nullptr;
    HANDLE mutex = nullptr;
    HANDLE response = nullptr;

    while (running_.load()) {
        if (view == nullptr) {
            section = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, kTsfSharedMemName);
            if (section != nullptr) {
                view = MapViewOfFile(section, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(TsfBridgeFrame));
            }
            mutex = OpenMutexW(SYNCHRONIZE | MUTEX_MODIFY_STATE, FALSE, kTsfMutexName);
            response = OpenEventW(EVENT_MODIFY_STATE, FALSE, kTsfResponseEventName);
            if (view == nullptr || mutex == nullptr || response == nullptr) {
                // skey-tray.exe is not running yet; retry quietly.
                if (view != nullptr) UnmapViewOfFile(view);
                if (section != nullptr) CloseHandle(section);
                if (mutex != nullptr) CloseHandle(mutex);
                if (response != nullptr) CloseHandle(response);
                view = nullptr;
                section = nullptr;
                mutex = nullptr;
                response = nullptr;
                Sleep(500);
                continue;
            }
        }

        if (WaitForSingleObject(request, 250) != WAIT_OBJECT_0) continue;

        TsfBridgeFrame frame{};
        const DWORD lock_rc = WaitForSingleObject(mutex, INFINITE);
        if (lock_rc != WAIT_OBJECT_0 && lock_rc != WAIT_ABANDONED) continue;
        std::memcpy(&frame, view, sizeof(frame));
        ReleaseMutex(mutex);
        if (frame.magic != kTsfBridgeMagic || frame.version != kTsfBridgeVersion ||
            frame.type != static_cast<std::uint32_t>(TsfBridgeMsg::push) ||
            frame.target_pid != GetCurrentProcessId() || frame.text_len > kTsfMaxTextUnits) {
            continue;
        }

        BridgeApplyMsg apply{};
        apply.backspaces = frame.backspaces;
        apply.text_len = frame.text_len;
        std::memcpy(apply.text, frame.text, frame.text_len * sizeof(wchar_t));

        DWORD_PTR result = 0;
        const HWND target = window_.load();
        const bool applied =
            target != nullptr &&
            SendMessageTimeoutW(target, kSKeyTsfApplyMessage, 0,
                                reinterpret_cast<LPARAM>(&apply), SMTO_BLOCK | SMTO_ABORTIFHUNG,
                                25, &result) != 0 &&
            result != 0;

        if (WaitForSingleObject(mutex, INFINITE) == WAIT_OBJECT_0) {
            auto* shared = static_cast<TsfBridgeFrame*>(view);
            shared->type = static_cast<std::uint32_t>(TsfBridgeMsg::response);
            shared->status = applied ? 0 : 1;
            ReleaseMutex(mutex);
        }
        SetEvent(response);
    }

    if (view != nullptr) UnmapViewOfFile(view);
    if (section != nullptr) CloseHandle(section);
    if (mutex != nullptr) CloseHandle(mutex);
    if (response != nullptr) CloseHandle(response);
    if (request != nullptr) CloseHandle(request);
}

} // namespace skey::tsf
