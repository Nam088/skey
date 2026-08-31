#include "ClipboardMonitor.h"

#include <chrono>
#include <cstddef>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

namespace {

std::int64_t now_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

} // namespace

ClipboardMonitor::ClipboardMonitor(Capture capture) : capture_(std::move(capture)) {}

ClipboardMonitor::~ClipboardMonitor() { stop(); }

void ClipboardMonitor::start() {
    bool expected = false;
    if (!running_.compare_exchange_strong(expected, true)) return;
    thread_ = std::thread(&ClipboardMonitor::loop, this);
}

void ClipboardMonitor::stop() {
    if (!running_.exchange(false)) return;
    if (thread_.joinable()) thread_.join();
}

void ClipboardMonitor::pause_for(std::chrono::milliseconds duration) {
    paused_until_ms_.store(now_ms() + duration.count());
}

#ifdef _WIN32

namespace {

std::string read_clipboard_text_utf8() {
    if (OpenClipboard(nullptr) == FALSE) return {};
    std::string result;
    const HANDLE data = GetClipboardData(CF_UNICODETEXT);
    if (data != nullptr) {
        const auto* wide = static_cast<const wchar_t*>(GlobalLock(data));
        if (wide != nullptr) {
            const int length = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
            if (length > 1) {
                result.resize(static_cast<std::size_t>(length - 1));
                WideCharToMultiByte(CP_UTF8, 0, wide, -1, result.data(), length, nullptr, nullptr);
            } else if (length == 1) {
                result.clear();
            }
            GlobalUnlock(data);
        }
    }
    CloseClipboard();
    return result;
}

} // namespace

void ClipboardMonitor::loop() {
    DWORD last_sequence = GetClipboardSequenceNumber();
    while (running_.load()) {
        Sleep(500);
        if (!running_.load()) break;

        const DWORD sequence = GetClipboardSequenceNumber();
        if (sequence == last_sequence) continue;
        last_sequence = sequence;

        if (now_ms() < paused_until_ms_.load()) continue;

        std::string text = read_clipboard_text_utf8();
        if (!text.empty() && capture_) capture_(std::move(text));
    }
}

#else // Non-Windows: tests exercise the store/pipeline directly.

void ClipboardMonitor::loop() {}

#endif

} // namespace skey::windows
