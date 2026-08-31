#include "ClipboardHistoryStore.h"

#include "ClipboardText.h"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <fstream>
#include <sstream>

namespace {

bool is_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

std::size_t skip_space(const std::string& text, std::size_t at) {
    while (at < text.size() && is_space(text[at])) ++at;
    return at;
}

bool read_quoted(const std::string& text, std::size_t& at, std::string& out) {
    if (at >= text.size() || text[at] != '"') return false;
    std::string result;
    ++at;
    while (at < text.size()) {
        const char c = text[at];
        if (c == '"') {
            ++at;
            out = std::move(result);
            return true;
        }
        if (c == '\\') {
            if (at + 1 >= text.size()) return false;
            switch (text[at + 1]) {
            case 'n': result += '\n'; break;
            case 't': result += '\t'; break;
            case 'r': result += '\r'; break;
            case '"': result += '"'; break;
            case '\\': result += '\\'; break;
            case '/': result += '/'; break;
            default: return false;
            }
            at += 2;
            continue;
        }
        result += c;
        ++at;
    }
    return false;
}

std::size_t find_value(const std::string& text, const std::string& key, const std::string& allowed_first) {
    const auto marker = "\"" + key + "\"";
    std::size_t at = 0;
    while ((at = text.find(marker, at)) != std::string::npos) {
        const auto colon = skip_space(text, at + marker.size());
        if (colon < text.size() && text[colon] == ':') {
            const auto value_at = skip_space(text, colon + 1);
            if (value_at < text.size() && allowed_first.find(text[value_at]) != std::string::npos) {
                return value_at;
            }
        }
        at += marker.size();
    }
    return std::string::npos;
}

std::string value_for(const std::string& text, const std::string& key) {
    const auto at = find_value(text, key, "\"");
    if (at == std::string::npos) return {};
    auto cursor = at;
    std::string out;
    return read_quoted(text, cursor, out) ? out : std::string{};
}

bool bool_value_for(const std::string& text, const std::string& key, bool fallback) {
    const auto at = find_value(text, key, "tf");
    if (at == std::string::npos) return fallback;
    if (text.compare(at, 4, "true") == 0) return true;
    if (text.compare(at, 5, "false") == 0) return false;
    return fallback;
}

std::uint64_t int_value_for(const std::string& text, const std::string& key, std::uint64_t fallback) {
    const auto at = find_value(text, key, "0123456789");
    if (at == std::string::npos) return fallback;
    std::uint64_t value = 0;
    auto cursor = at;
    bool any = false;
    while (cursor < text.size() && std::isdigit(static_cast<unsigned char>(text[cursor]))) {
        value = value * 10 + static_cast<std::uint64_t>(text[cursor] - '0');
        any = true;
        ++cursor;
    }
    return any ? value : fallback;
}

std::string json_escape(const std::string& value) {
    std::string out;
    out.reserve(value.size());
    for (const char c : value) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\t': out += "\\t"; break;
        case '\r': out += "\\r"; break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buffer[8];
                std::snprintf(buffer, sizeof(buffer), "\\u%04x", static_cast<unsigned>(static_cast<unsigned char>(c)));
                out += buffer;
            } else {
                out += c;
            }
        }
    }
    return out;
}

std::string bool_str(bool v) { return v ? "true" : "false"; }

} // namespace

namespace skey::windows {

ClipboardHistoryStore::ClipboardHistoryStore(std::filesystem::path file) : file_(std::move(file)) {}

bool ClipboardHistoryStore::load() {
    std::ifstream input(file_);
    if (!input.good()) return false;
    std::ostringstream buffer;
    buffer << input.rdbuf();
    const auto text = buffer.str();

    // Restrict parsing to the "items" array so the outer JSON object is
    // never mistaken for an item.
    const auto items_key = text.find("\"items\"");
    if (items_key == std::string::npos) return false;
    const auto array_open = text.find('[', items_key);
    if (array_open == std::string::npos) return false;
    int depth = 0;
    bool in_string = false;
    std::size_t array_end = std::string::npos;
    for (std::size_t i = array_open; i < text.size(); ++i) {
        const char c = text[i];
        if (in_string) {
            if (c == '\\') {
                if (i + 1 >= text.size()) break;
                ++i;
            } else if (c == '"') {
                in_string = false;
            }
        } else if (c == '"') {
            in_string = true;
        } else if (c == '[' || c == '{') {
            ++depth;
        } else if (c == ']' || c == '}') {
            --depth;
            if (depth == 0) {
                if (c == ']') array_end = i;
                break;
            }
        }
    }
    if (array_end == std::string::npos) return false;

    std::vector<ClipboardHistoryItem> parsed;
    std::size_t at = array_open + 1;
    while ((at = text.find('{', at)) != std::string::npos && at < array_end) {
        int object_depth = 0;
        bool object_in_string = false;
        std::size_t end = at;
        bool closed = false;
        for (; end < text.size(); ++end) {
            const char c = text[end];
            if (object_in_string) {
                if (c == '\\') {
                    if (end + 1 >= text.size()) break;
                    ++end;
                } else if (c == '"') {
                    object_in_string = false;
                }
            } else if (c == '"') {
                object_in_string = true;
            } else if (c == '{') {
                ++object_depth;
            } else if (c == '}') {
                --object_depth;
                if (object_depth == 0) {
                    closed = true;
                    break;
                }
            }
        }
        if (!closed) break;
        const std::string object = text.substr(at, end - at + 1);
        at = end + 1;

        ClipboardHistoryItem item;
        item.hash = value_for(object, "hash");
        item.text = value_for(object, "text");
        if (item.hash.empty()) continue;
        item.pinned = bool_value_for(object, "pinned", false);
        item.first_copied_at = int_value_for(object, "firstCopiedAt", 0);
        item.last_copied_at = int_value_for(object, "lastCopiedAt", item.first_copied_at);
        item.copy_count = int_value_for(object, "copyCount", 1);
        item.folded = ClipboardText::fold(item.text);
        parsed.push_back(std::move(item));
    }

    std::stable_sort(parsed.begin(), parsed.end(), [](const ClipboardHistoryItem& a, const ClipboardHistoryItem& b) {
        return a.last_copied_at > b.last_copied_at;
    });
    items_ = std::move(parsed);
    trim();
    return true;
}

bool ClipboardHistoryStore::save() const {
    std::error_code error;
    if (!file_.parent_path().empty()) {
        std::filesystem::create_directories(file_.parent_path(), error);
        if (error) return false;
    }
    std::ofstream output(file_, std::ios::trunc);
    if (!output.good()) return false;

    output << "{\n  \"items\": [";
    for (std::size_t i = 0; i < items_.size(); ++i) {
        const auto& item = items_[i];
        output << (i == 0 ? "" : ",") << "\n    {"
               << "\"hash\": \"" << json_escape(item.hash) << "\", "
               << "\"text\": \"" << json_escape(item.text) << "\", "
               << "\"pinned\": " << bool_str(item.pinned) << ", "
               << "\"firstCopiedAt\": " << item.first_copied_at << ", "
               << "\"lastCopiedAt\": " << item.last_copied_at << ", "
               << "\"copyCount\": " << item.copy_count << "}";
    }
    output << (items_.empty() ? "" : "\n  ") << "]\n}\n";
    return output.good();
}

void ClipboardHistoryStore::set_max_items(std::size_t n) {
    max_items_ = n == 0 ? 1 : n;
    trim();
}

std::size_t ClipboardHistoryStore::add_text(const std::string& text, std::uint64_t now_ms) {
    const auto hash = ClipboardText::sha256_hex(text);
    for (std::size_t i = 0; i < items_.size(); ++i) {
        if (items_[i].hash == hash) {
            ClipboardHistoryItem bumped = items_[i];
            bumped.last_copied_at = now_ms;
            bumped.copy_count += 1;
            items_.erase(items_.begin() + static_cast<std::ptrdiff_t>(i));
            items_.insert(items_.begin(), std::move(bumped));
            return 0;
        }
    }

    ClipboardHistoryItem item;
    item.hash = hash;
    item.text = text;
    item.first_copied_at = now_ms;
    item.last_copied_at = now_ms;
    item.copy_count = 1;
    item.folded = ClipboardText::fold(text);
    items_.insert(items_.begin(), std::move(item));
    trim();
    return 0;
}

void ClipboardHistoryStore::set_pinned(std::size_t index, bool pinned) {
    if (index < items_.size()) items_[index].pinned = pinned;
}

void ClipboardHistoryStore::remove(std::size_t index) {
    if (index < items_.size()) items_.erase(items_.begin() + static_cast<std::ptrdiff_t>(index));
}

void ClipboardHistoryStore::clear_unpinned() {
    std::erase_if(items_, [](const ClipboardHistoryItem& item) { return !item.pinned; });
}

void ClipboardHistoryStore::clear_all() { items_.clear(); }

std::vector<std::size_t> ClipboardHistoryStore::search(const std::string& query) const {
    std::vector<std::size_t> indexes(items_.size());
    for (std::size_t i = 0; i < items_.size(); ++i) indexes[i] = i;
    if (query.empty()) return indexes;

    struct Scored {
        std::size_t index;
        long long score;
    };
    std::vector<Scored> scored;
    scored.reserve(items_.size());
    for (std::size_t i = 0; i < items_.size(); ++i) {
        const auto score = ClipboardText::rank(items_[i].text, items_[i].folded, query);
        if (score >= 0) scored.push_back({i, score});
    }
    std::stable_sort(scored.begin(), scored.end(), [](const Scored& a, const Scored& b) {
        return a.score > b.score;
    });
    std::vector<std::size_t> result;
    result.reserve(scored.size());
    for (const auto& entry : scored) result.push_back(entry.index);
    return result;
}

void ClipboardHistoryStore::trim() {
    // The limit counts unpinned items; pinned entries always survive.
    std::size_t unpinned = 0;
    for (const auto& item : items_) {
        if (!item.pinned) ++unpinned;
    }
    for (std::size_t i = items_.size(); i > 0 && unpinned > max_items_; --i) {
        const std::size_t index = i - 1;
        if (!items_[index].pinned) {
            items_.erase(items_.begin() + static_cast<std::ptrdiff_t>(index));
            --unpinned;
        }
    }
}

} // namespace skey::windows
