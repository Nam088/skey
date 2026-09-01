#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace skey::windows {

struct ClipboardHistoryItem {
    std::string hash;  // SHA-256 of content; doubles as stable id
    std::string text;  // UTF-8
    bool pinned = false;
    std::uint64_t first_copied_at = 0;  // ms since epoch
    std::uint64_t last_copied_at = 0;
    std::uint64_t copy_count = 1;
    std::string folded;  // cached ClipboardText::fold(text)
};

// Persistent clipboard history, mirroring the macOS SQLiteClipboardRepository
// behavior: newest-first ordering, SHA-256 dedup that bumps recency and
// copyCount, and pin-aware trimming (limit counts unpinned items).
class ClipboardHistoryStore {
public:
    explicit ClipboardHistoryStore(std::filesystem::path file);

    bool load();
    bool save() const;

    void set_max_items(std::size_t n);
    std::size_t max_items() const { return max_items_; }

    // Adds text (or bumps the existing item with the same hash).
    // Returns the resulting index in items().
    std::size_t add_text(const std::string& text, std::uint64_t now_ms);

    void set_pinned(std::size_t index, bool pinned);
    void remove(std::size_t index);
    void clear_unpinned();
    void clear_all();

    const std::vector<ClipboardHistoryItem>& items() const { return items_; }

    // Indexes into items(), ordered by ClipboardText::rank (best first).
    // Empty query returns all indexes in current order.
    std::vector<std::size_t> search(const std::string& query) const;

private:
    void trim();

    std::filesystem::path file_;
    std::vector<ClipboardHistoryItem> items_;
    std::size_t max_items_ = 100;
};

} // namespace skey::windows
