#pragma once
#include <cstdint>
namespace skey::windows { struct ShortcutModel { std::uint32_t key_code{0}; std::uint32_t modifiers{0}; bool enabled{true}; }; }
