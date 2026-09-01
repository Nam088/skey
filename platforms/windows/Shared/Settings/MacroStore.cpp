#include "MacroStore.h"

#include <algorithm>
#include <cstdio>
#include <fstream>
#include <sstream>

namespace {

bool is_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

std::size_t skip_space(const std::string& text, std::size_t at) {
    while (at < text.size() && is_space(text[at])) ++at;
    return at;
}

std::string trimmed(const std::string& text) {
    const char* ws = " \t\n\r";
    const auto first = text.find_first_not_of(ws);
    if (first == std::string::npos) return {};
    const auto last = text.find_last_not_of(ws);
    return text.substr(first, last - first + 1);
}

std::string lowercased(std::string text) {
    for (auto& c : text) {
        if (c >= 'A' && c <= 'Z') c = static_cast<char>(c - 'A' + 'a');
    }
    return text;
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

std::string value_for(const std::string& text, const std::string& key) {
    const auto at = find_value(text, key, "\"");
    if (at == std::string::npos) return {};
    auto cursor = at;
    std::string out;
    return read_quoted(text, cursor, out) ? out : std::string{};
}

bool read_array_block(const std::string& text, std::size_t at, std::string& inner) {
    if (at >= text.size() || text[at] != '[') return false;
    int depth = 0;
    bool in_string = false;
    for (std::size_t i = at; i < text.size(); ++i) {
        const char c = text[i];
        if (in_string) {
            if (c == '\\') {
                if (i + 1 >= text.size()) return false;
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
                if (c != ']') return false;
                inner = text.substr(at + 1, i - at - 1);
                return true;
            }
        }
    }
    return false;
}

bool split_objects(const std::string& inner, std::vector<std::string>& objects) {
    std::vector<std::string> parsed;
    auto cursor = skip_space(inner, 0);
    while (cursor < inner.size()) {
        if (inner[cursor] != '{') return false;
        int depth = 0;
        bool in_string = false;
        bool closed = false;
        auto end = cursor;
        for (; end < inner.size(); ++end) {
            const char c = inner[end];
            if (in_string) {
                if (c == '\\') {
                    if (end + 1 >= inner.size()) return false;
                    ++end;
                } else if (c == '"') {
                    in_string = false;
                }
            } else if (c == '"') {
                in_string = true;
            } else if (c == '{') {
                ++depth;
            } else if (c == '}') {
                --depth;
                if (depth == 0) {
                    closed = true;
                    break;
                }
            }
        }
        if (!closed) return false;
        parsed.push_back(inner.substr(cursor, end - cursor + 1));
        cursor = skip_space(inner, end + 1);
        if (cursor < inner.size() && inner[cursor] == ',') {
            cursor = skip_space(inner, cursor + 1);
            continue;
        }
        break;
    }
    if (skip_space(inner, cursor) != inner.size()) return false;
    objects = std::move(parsed);
    return true;
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

bool valid_trigger(const std::string& trigger) {
    if (trigger.empty() || trigger.size() > skey::windows::MacroStore::kMaxTriggerLength) return false;
    return std::all_of(trigger.begin(), trigger.end(), [](char c) { return c >= 33 && c <= 126; });
}

bool valid_replacement(const std::string& replacement) {
    return !replacement.empty() && replacement.size() <= skey::windows::MacroStore::kMaxReplacementLength;
}

} // namespace

namespace skey::windows {

namespace {

// Normalizes and validates like add(); keeps the first occurrence per trigger.
std::vector<MacroEntry> sanitized(std::vector<MacroEntry> entries) {
    std::vector<MacroEntry> result;
    result.reserve(entries.size());
    for (auto& entry : entries) {
        entry.trigger = lowercased(trimmed(entry.trigger));
        entry.replacement = trimmed(entry.replacement);
        if (!valid_trigger(entry.trigger) || !valid_replacement(entry.replacement)) continue;
        const auto duplicate = std::any_of(result.begin(), result.end(),
            [&entry](const MacroEntry& kept) { return kept.trigger == entry.trigger; });
        if (duplicate) continue;
        result.push_back(std::move(entry));
    }
    return result;
}

} // namespace

MacroStore::MacroStore(std::filesystem::path path)
    : path_(path.extension().empty() ? path / "macros.json" : std::move(path)) {}

std::vector<MacroEntry> MacroStore::load() const {
    std::ifstream input(path_);
    if (!input.good()) return {};
    std::ostringstream buffer;
    buffer << input.rdbuf();
    const auto text = buffer.str();

    const auto at = find_value(text, "macros", "[");
    if (at == std::string::npos) return {};
    std::string inner;
    if (!read_array_block(text, at, inner)) return {};
    std::vector<std::string> objects;
    if (!split_objects(inner, objects)) return {};

    std::vector<MacroEntry> entries;
    entries.reserve(objects.size());
    for (const auto& object : objects) {
        entries.push_back({value_for(object, "trigger"), value_for(object, "replacement")});
    }
    return sanitized(std::move(entries));
}

bool MacroStore::save(const std::vector<MacroEntry>& entries) const {
    std::error_code error;
    if (!path_.parent_path().empty()) {
        std::filesystem::create_directories(path_.parent_path(), error);
        if (error) return false;
    }
    std::ofstream output(path_, std::ios::trunc);
    if (!output.good()) return false;

    const auto valid = sanitized(entries);
    output << "{\n  \"schemaVersion\": 1,\n  \"macros\": [";
    for (std::size_t i = 0; i < valid.size(); ++i) {
        output << (i == 0 ? "" : ",")
               << "\n    {\"trigger\": \"" << json_escape(valid[i].trigger)
               << "\", \"replacement\": \"" << json_escape(valid[i].replacement) << "\"}";
    }
    output << (valid.empty() ? "" : "\n  ") << "]\n}\n";
    return output.good();
}

bool MacroStore::add(const std::string& trigger, const std::string& replacement) {
    MacroEntry entry{lowercased(trimmed(trigger)), trimmed(replacement)};
    if (!valid_trigger(entry.trigger) || !valid_replacement(entry.replacement)) return false;
    auto entries = load();
    for (auto& existing : entries) {
        if (existing.trigger == entry.trigger) {
            existing.replacement = entry.replacement;
            return save(entries);
        }
    }
    entries.insert(entries.begin(), std::move(entry));
    return save(entries);
}

bool MacroStore::update(const std::string& old_trigger, const std::string& new_trigger, const std::string& replacement) {
    MacroEntry entry{lowercased(trimmed(new_trigger)), trimmed(replacement)};
    if (!valid_trigger(entry.trigger) || !valid_replacement(entry.replacement)) return false;
    const auto old_key = lowercased(trimmed(old_trigger));
    auto entries = load();
    const auto current = std::find_if(entries.begin(), entries.end(),
        [&old_key](const MacroEntry& candidate) { return candidate.trigger == old_key; });
    if (current == entries.end()) return false;
    entries.erase(current);
    for (auto& existing : entries) {
        if (existing.trigger == entry.trigger) {
            existing.replacement = entry.replacement;
            return save(entries);
        }
    }
    entries.insert(entries.begin(), std::move(entry));
    return save(entries);
}

bool MacroStore::remove(const std::string& trigger) {
    const auto key = lowercased(trimmed(trigger));
    auto entries = load();
    const auto before = entries.size();
    entries.erase(std::remove_if(entries.begin(), entries.end(),
        [&key](const MacroEntry& candidate) { return candidate.trigger == key; }), entries.end());
    if (entries.size() == before) return false;
    return save(entries);
}

std::vector<std::pair<std::string, std::string>> MacroStore::entries_as_pairs() const {
    auto entries = load();
    std::vector<std::pair<std::string, std::string>> pairs;
    pairs.reserve(entries.size());
    for (auto& entry : entries) {
        pairs.emplace_back(std::move(entry.trigger), std::move(entry.replacement));
    }
    return pairs;
}

} // namespace skey::windows
