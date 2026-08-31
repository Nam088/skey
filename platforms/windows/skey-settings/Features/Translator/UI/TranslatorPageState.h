#pragma once
#include <string>
namespace skey::windows { struct TranslatorPageState { bool loading{false}; bool error{false}; std::string source; std::string result; }; }
