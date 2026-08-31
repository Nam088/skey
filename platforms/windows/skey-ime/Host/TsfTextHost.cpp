#ifdef _WIN32
#include "TsfTextHost.h"
#include <msctf.h>
#include <olectl.h>

namespace skey::windows {

std::wstring TsfTextHost::utf8_to_wide(std::string_view utf8) {
    if (utf8.empty()) return {};
    const int needed = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                            static_cast<int>(utf8.size()), nullptr, 0);
    if (needed <= 0) return {};
    std::wstring result(static_cast<std::size_t>(needed), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        result.data(), needed);
    return result;
}

bool TsfTextHost::delete_previous(unsigned count) {
    if (context_ == nullptr || count == 0) return false;
    // Simplified: TSF text deletion requires edit cookie and proper range manipulation
    // This is a placeholder that will be implemented when we have proper TSF context access
    (void)count;
    return false;
}

bool TsfTextHost::insert_text(std::string_view utf8) {
    if (context_ == nullptr || utf8.empty()) return false;

    const auto wide = utf8_to_wide(utf8);
    if (wide.empty()) return false;

    // Simplified: TSF text insertion requires edit cookie and proper range manipulation
    // This is a placeholder that will be implemented when we have proper TSF context access
    (void)wide;
    return false;
}

bool TsfTextHost::replace_selection(std::string_view utf8) {
    if (context_ == nullptr) return false;

    const auto wide = utf8_to_wide(utf8);

    // Simplified: TSF selection replacement requires edit cookie and proper range manipulation
    // This is a placeholder that will be implemented when we have proper TSF context access
    (void)wide;
    return false;
}

void TsfTextHost::commit() {
}

void TsfTextHost::reset() {
}

} // namespace skey::windows
#endif
