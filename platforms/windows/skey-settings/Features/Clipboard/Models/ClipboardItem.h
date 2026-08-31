#pragma once
#include <cstdint>
#include <string>
namespace skey::windows { struct ClipboardItem { std::uint64_t id{}; std::string text; bool pinned{false}; bool sensitive{false}; }; }
