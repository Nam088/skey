#pragma once

#ifdef _WIN32
#include "ITextHost.h"
#include <windows.h>
#include <msctf.h>

#include <string>

namespace skey::windows {

class TsfTextHost final : public ITextHost {
public:
    explicit TsfTextHost(ITfContext* context = nullptr) noexcept : context_(context) {}

    bool delete_previous(unsigned count) override;
    bool insert_text(std::string_view utf8) override;
    bool replace_selection(std::string_view utf8) override;
    void commit() override;
    void reset() override;

    void set_context(ITfContext* context) noexcept { context_ = context; }
    ITfContext* context() const noexcept { return context_; }

private:
    static std::wstring utf8_to_wide(std::string_view utf8);
    bool delete_range(ITfRange* range);

    ITfContext* context_{nullptr};
};

} // namespace skey::windows
#endif
