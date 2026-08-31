#pragma once
#include <string>
namespace skey::windows { enum class LogLevel { info, warning, error }; struct LogEntry { LogLevel level{LogLevel::info}; std::string message; }; }
