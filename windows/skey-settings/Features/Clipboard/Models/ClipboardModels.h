#pragma once
#include <string>
#include <cstdint>
namespace skey::windows { struct ClipboardItem { std::uint64_t id{0}; std::string text; bool pinned{false}; }; }
