#pragma once
#include <string>
namespace skey::windows { struct ShortcutRecorderModel { bool recording{false}; std::string value; bool conflict{false}; void begin() { recording = true; conflict = false; } void cancel() { recording = false; } }; }
