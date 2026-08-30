#include "CoreEngineAdapter.h"

#include <skey.h>

#include <algorithm>
#include <array>
#include <string_view>

namespace skey::windows {

CoreEngineAdapter::CoreEngineAdapter() : engine_(skey_engine_create()) {}

CoreEngineAdapter::~CoreEngineAdapter() {
    if (engine_ != nullptr) {
        skey_engine_free(engine_);
    }
}

EditResult CoreEngineAdapter::filter(std::uint32_t codepoint) {
    if (engine_ == nullptr) return {};
    return read_edit(skey_engine_filter(engine_, codepoint));
}

EditResult CoreEngineAdapter::backspace() {
    if (engine_ == nullptr) return {};
    return read_edit(skey_engine_backspace(engine_));
}

void CoreEngineAdapter::reset() {
    if (engine_ != nullptr) skey_engine_reset(engine_);
}

EditResult CoreEngineAdapter::read_edit(::SKeyEdit edit) {
    if (edit.handled == 0 || edit.len <= 0) {
        return {.handled = edit.handled != 0,
                .backspaces = static_cast<std::uint16_t>(std::clamp(edit.backspaces, 0, 65535))};
    }

    // The Rust C ABI documents output as a borrowed buffer. Keep this view
    // valid only until the next engine call, matching the host apply contract.
    static thread_local std::array<char, 4096> output{};
    const auto limit = static_cast<int>(output.size() - 1);
    const auto written = skey_engine_output(engine_, reinterpret_cast<unsigned char*>(output.data()), limit);
    const auto length = std::clamp(written, 0, limit);
    return {.handled = true,
            .backspaces = static_cast<std::uint16_t>(std::clamp(edit.backspaces, 0, 65535)),
            .text = std::string_view(output.data(), static_cast<std::size_t>(length))};
}

} // namespace skey::windows
