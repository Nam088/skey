#pragma once
#include "../Models/ClipboardItem.h"
#include <algorithm>
#include <cstddef>
#include <vector>

namespace skey::windows {

class ClipboardService {
public:
    void add(ClipboardItem item) {
        items_.insert(items_.begin(), std::move(item));
        trim();
    }

    void remove(std::size_t index) {
        if (index < items_.size()) items_.erase(items_.begin() + static_cast<std::ptrdiff_t>(index));
    }

    void pin(std::size_t index) {
        if (index < items_.size()) items_[index].pinned = true;
    }

    void unpin(std::size_t index) {
        if (index < items_.size()) items_[index].pinned = false;
    }

    void clear() { items_.clear(); }

    void set_max_items(std::size_t n) {
        max_items_ = n;
        trim();
    }

    std::size_t max_items() const { return max_items_; }

    const std::vector<ClipboardItem>& items() const { return items_; }

private:
    void trim() {
        while (items_.size() > max_items_) {
            auto it = std::find_if(items_.rbegin(), items_.rend(), [](const ClipboardItem& i) { return !i.pinned; });
            if (it == items_.rend()) break;
            items_.erase(std::prev(it.base()));
        }
    }

    std::vector<ClipboardItem> items_;
    std::size_t max_items_{100};
};

} // namespace skey::windows
