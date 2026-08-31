#pragma once
#include "../../../Shared/Contracts/SettingsModel.h"
namespace skey::windows {
struct KeyboardFeature {
    InputMethod method{InputMethod::telex};
    std::string charset{"unicode"};
    bool spell_check{true};
    bool free_marking{true};
    bool modern_style{false};
    bool swallowed_key_restore{true};
    bool quick_telex{false};
    bool quick_start_consonant{false};
    bool quick_end_consonant{false};
    bool upper_case_first_char{false};
    bool allow_consonant_zfwj{false};
    bool smart_app_switch{false};
};
}
