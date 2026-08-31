#pragma once
#include "../Models/TranslatorModels.h"
namespace skey::windows { class TranslatorService { public: TranslatorModel translate(const std::string& source) const { return TranslatorModel{source, {}, false}; } }; }
