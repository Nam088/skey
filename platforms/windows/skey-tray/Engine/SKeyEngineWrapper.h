#pragma once

#include <skey.h>

#include <mutex>
#include <string>

#include "EngineInterface.h"

namespace skey::windows {

enum class EngineInputMethod : int {
    telex = 0,
    vni = 1,
    viqr = 2,
    simple_telex = 5,
};

// Thread-safe wrapper around the Rust skey-capi engine.
// Port of platforms/macos/.../SKeyEngine.swift (same default options,
// same stack-buffer output reading, no heap allocation on the hot path).
class SKeyEngineWrapper : public EngineInterface {
public:
    using Result = EngineInterface::Result;

    SKeyEngineWrapper();
    ~SKeyEngineWrapper() override;
    SKeyEngineWrapper(const SKeyEngineWrapper&) = delete;
    SKeyEngineWrapper& operator=(const SKeyEngineWrapper&) = delete;

    void setup_default_options();
    void set_input_method(EngineInputMethod method);
    void set_spell_check(bool enabled);
    void set_modern_style(bool enabled);
    void set_free_marking(bool enabled);
    void set_swallowed_key_restore(bool enabled);
    void set_quick_telex(bool enabled);
    void set_quick_start_consonant(bool enabled);
    void set_quick_end_consonant(bool enabled);
    void set_upper_case_first_char(bool enabled);
    void set_allow_consonant_zfwj(bool enabled);
    void reset() override;
    void set_caps_state(bool shift_pressed, bool caps_lock_on) override;

    Result filter(char32_t character) override;
    Result backspace() override;
    Result restore() override;

private:
    template <typename Mutate>
    void set_option(Mutate&& mutate) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (engine_ == nullptr) return;
        SKeyOptions opt{};
        skey_engine_get_options(engine_, &opt);
        mutate(opt);
        skey_engine_set_options(engine_, &opt);
    }

    Result read_result(const SKeyEdit& edit);

    SKeyEngine* engine_ = nullptr;
    std::mutex mutex_;
};

} // namespace skey::windows
