#include "SKeyEngineWrapper.h"

#include <array>
#include <cstddef>

namespace skey::windows {

SKeyEngineWrapper::SKeyEngineWrapper() {
    engine_ = skey_engine_create();
    setup_default_options();
}

SKeyEngineWrapper::~SKeyEngineWrapper() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ != nullptr) {
        skey_engine_free(engine_);
        engine_ = nullptr;
    }
}

void SKeyEngineWrapper::setup_default_options() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;

    SKeyOptions opt{};
    opt.freeMarking = 1;
    opt.modernStyle = 0;
    opt.macroEnabled = 0;
    opt.useUnicodeClipboard = 0;
    opt.alwaysMacro = 0;
    opt.strictSpellCheck = 0;
    opt.useIME = 1;
    opt.spellCheckEnabled = 1;
    opt.autoNonVnRestore = 1;
    skey_engine_set_options(engine_, &opt);

    skey_engine_set_charset(engine_, 12);  // XUTF8
    skey_engine_set_input_method_raw(engine_, static_cast<int>(InputMethod::telex));
    skey_engine_set_swallowed_key_restore(engine_, 1);
    skey_engine_set_quick_telex(engine_, 0);
    skey_engine_set_quick_start_consonant(engine_, 0);
    skey_engine_set_quick_end_consonant(engine_, 0);
    skey_engine_set_upper_case_first_char(engine_, 0);
    skey_engine_set_allow_consonant_zfwj(engine_, 0);
}

void SKeyEngineWrapper::set_input_method(InputMethod method) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_input_method_raw(engine_, static_cast<int>(method));
    skey_engine_reset(engine_);
}

void SKeyEngineWrapper::set_spell_check(bool enabled) {
    const int v = enabled ? 1 : 0;
    set_option([v](SKeyOptions& opt) {
        opt.spellCheckEnabled = v;
        opt.autoNonVnRestore = v;
    });
}

void SKeyEngineWrapper::set_modern_style(bool enabled) {
    const int v = enabled ? 1 : 0;
    set_option([v](SKeyOptions& opt) { opt.modernStyle = v; });
}

void SKeyEngineWrapper::set_free_marking(bool enabled) {
    const int v = enabled ? 1 : 0;
    set_option([v](SKeyOptions& opt) { opt.freeMarking = v; });
}

void SKeyEngineWrapper::set_swallowed_key_restore(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_swallowed_key_restore(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::set_quick_telex(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_quick_telex(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::set_quick_start_consonant(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_quick_start_consonant(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::set_quick_end_consonant(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_quick_end_consonant(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::set_upper_case_first_char(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_upper_case_first_char(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::set_allow_consonant_zfwj(bool enabled) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return;
    skey_engine_set_allow_consonant_zfwj(engine_, enabled ? 1 : 0);
}

void SKeyEngineWrapper::reset() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ != nullptr) skey_engine_reset(engine_);
}

void SKeyEngineWrapper::set_caps_state(bool shift_pressed, bool caps_lock_on) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ != nullptr) {
        skey_engine_set_caps_state(engine_, shift_pressed ? 1 : 0, caps_lock_on ? 1 : 0);
    }
}

SKeyEngineWrapper::Result SKeyEngineWrapper::filter(char32_t character) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return Result{};
    const SKeyEdit edit = skey_engine_filter(engine_, static_cast<unsigned>(character));
    return edit.handled != 0 ? read_result(edit) : Result{};
}

SKeyEngineWrapper::Result SKeyEngineWrapper::backspace() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return Result{};
    const SKeyEdit edit = skey_engine_backspace(engine_);
    return edit.handled != 0 ? read_result(edit) : Result{};
}

SKeyEngineWrapper::Result SKeyEngineWrapper::restore() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (engine_ == nullptr) return Result{};
    const SKeyEdit edit = skey_engine_restore(engine_);
    return edit.handled != 0 ? read_result(edit) : Result{};
}

// Vietnamese words are strictly <= 64 bytes; use a stack buffer to avoid
// heap allocation in the output read path.
SKeyEngineWrapper::Result SKeyEngineWrapper::read_result(const SKeyEdit& edit) {
    Result result;
    result.handled = true;
    result.backspaces = edit.backspaces;
    if (edit.len <= 0 || engine_ == nullptr) return result;

    std::array<unsigned char, 68> buffer{};  // >= 64-byte word + slack
    const int written = skey_engine_output(engine_, buffer.data(), static_cast<int>(buffer.size()));
    if (written > 0) {
        result.text.assign(reinterpret_cast<const char*>(buffer.data()),
                           static_cast<std::size_t>(written));
    }
    return result;
}

} // namespace skey::windows
