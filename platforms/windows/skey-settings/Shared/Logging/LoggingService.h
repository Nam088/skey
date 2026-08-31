#pragma once
#include <string_view>
namespace skey::windows { class LoggingService { public: void debug(std::string_view) const noexcept {} void error(std::string_view) const noexcept {} }; }
