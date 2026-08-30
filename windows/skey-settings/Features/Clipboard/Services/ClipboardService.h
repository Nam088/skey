#pragma once
#include "../Models/ClipboardModels.h"
#include <vector>
namespace skey::windows { class ClipboardService { public: void clear() { items_.clear(); } const std::vector<ClipboardItem>& items() const { return items_; } private: std::vector<ClipboardItem> items_; }; }
