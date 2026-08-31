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

bool TsfTextHost::delete_range(ITfRange* range) {
    if (range == nullptr) return false;
    return SUCCEEDED(range->SetText(0, L"", 0));
}

bool TsfTextHost::delete_previous(unsigned count) {
    if (context_ == nullptr || count == 0) return false;

    ITfInsertAtSelection* insert = nullptr;
    HRESULT hr = context_->QueryInterface(IID_ITfInsertAtSelection,
                                           reinterpret_cast<void**>(&insert));
    if (FAILED(hr)) return false;

    ITfRange* range = nullptr;
    hr = insert->GetInsertionAtSelection(TF_IAS_QUERYONLY, &range);
    if (SUCCEEDED(hr) && range != nullptr) {
        LONG shifted = 0;
        hr = range->ShiftStart(TF_ANCHOR_END, -static_cast<LONG>(count), &shifted, nullptr);
        if (SUCCEEDED(hr)) {
            delete_range(range);
        }
        range->Release();
    }

    insert->Release();
    return SUCCEEDED(hr);
}

bool TsfTextHost::insert_text(std::string_view utf8) {
    if (context_ == nullptr || utf8.empty()) return false;

    const auto wide = utf8_to_wide(utf8);
    if (wide.empty()) return false;

    ITfInsertAtSelection* insert = nullptr;
    HRESULT hr = context_->QueryInterface(IID_ITfInsertAtSelection,
                                           reinterpret_cast<void**>(&insert));
    if (FAILED(hr)) return false;

    hr = insert->InsertTextAtSelection(0, wide.data(), static_cast<LONG>(wide.size()), nullptr);
    insert->Release();
    return SUCCEEDED(hr);
}

bool TsfTextHost::replace_selection(std::string_view utf8) {
    if (context_ == nullptr) return false;

    const auto wide = utf8_to_wide(utf8);

    ITfRange* range = nullptr;
    ULONG fetched = 0;
    HRESULT hr = context_->GetSelection(0, TF_TF_MOVESTART, 1, &range, &fetched);
    if (FAILED(hr) || range == nullptr) return false;

    hr = range->SetText(0, wide.data(), static_cast<LONG>(wide.size()));
    range->Release();
    return SUCCEEDED(hr);
}

void TsfTextHost::commit() {
}

void TsfTextHost::reset() {
}

} // namespace skey::windows
#endif
