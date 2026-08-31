#pragma once
#include <cstddef>
namespace skey::windows {
struct ClipboardFeature {
    bool enabled{true};
    std::size_t max_items{100};
    bool auto_paste{true};
    bool paste_plain_text{false};
    bool save_text{true};
    bool save_images{false};
    bool excluded_password_managers{true};
};
}
