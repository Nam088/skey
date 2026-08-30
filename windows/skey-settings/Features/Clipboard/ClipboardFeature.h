#pragma once
#include <cstddef>
namespace skey::windows { struct ClipboardFeature { bool enabled{true}; std::size_t max_items{100}; bool excluded_password_managers{true}; }; }
