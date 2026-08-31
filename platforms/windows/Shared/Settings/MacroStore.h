#pragma once

#include <cstddef>
#include <filesystem>
#include <string>
#include <utility>
#include <vector>

namespace skey::windows {

struct MacroEntry final {
    std::string trigger;
    std::string replacement;

    bool operator==(const MacroEntry&) const = default;
};

// Persists the snippet table in macros.json next to settings.json.
// The constructor accepts either the containing directory or the full file path.
class MacroStore final {
public:
    // Mirrors MacroEngine: typed words are capped at 64 chars and only
    // printable ASCII (33..126) can ever match a trigger.
    static constexpr std::size_t kMaxTriggerLength = 64;
    static constexpr std::size_t kMaxReplacementLength = 2048;

    explicit MacroStore(std::filesystem::path path);

    const std::filesystem::path& path() const { return path_; }

    std::vector<MacroEntry> load() const;
    bool save(const std::vector<MacroEntry>& entries) const;

    bool add(const std::string& trigger, const std::string& replacement);
    bool update(const std::string& old_trigger, const std::string& new_trigger, const std::string& replacement);
    bool remove(const std::string& trigger);

    std::vector<std::pair<std::string, std::string>> entries_as_pairs() const;

private:
    std::filesystem::path path_;
};

} // namespace skey::windows
