#include "../Shared/Settings/MacroStore.h"

#include <cassert>
#include <filesystem>
#include <fstream>
#include <string>
#include <utility>
#include <vector>

using namespace skey::windows;
namespace fs = std::filesystem;

namespace {

fs::path make_test_dir() {
    auto dir = fs::temp_directory_path() / "skey-macrostore-tests";
    std::error_code error;
    fs::remove_all(dir, error);
    fs::create_directories(dir);
    return dir;
}

fs::path make_case_dir(const fs::path& root, const std::string& name) {
    auto dir = root / name;
    fs::create_directories(dir);
    return dir;
}

void write_file(const fs::path& path, const std::string& content) {
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    output << content;
}

} // namespace

int main() {
    const auto root = make_test_dir();

    // Missing file: empty list, no crash.
    {
        MacroStore store(make_case_dir(root, "missing"));
        assert(store.load().empty());
        assert(store.entries_as_pairs().empty());
    }

    // Save/load round-trip through the directory constructor (macros.json
    // lives next to settings.json).
    {
        const auto dir = make_case_dir(root, "roundtrip");
        MacroStore store(dir);
        assert(store.path() == dir / "macros.json");
        std::vector<MacroEntry> entries{
            {"ko", "kh\303\264ng"},
            {"vn", "Vi\341\273\207t Nam"},
            {"skey", "SKey - B\341\271\231 g\341\275\235 ti\341\272\277ng Vi\341\273\207t Windows"},
        };
        assert(store.save(entries));
        assert(store.load() == entries);
    }

    // File-path constructor is used as-is.
    {
        const auto dir = make_case_dir(root, "file-path");
        const auto custom = dir / "custom.json";
        MacroStore store(custom);
        assert(store.path() == custom);
        assert(store.add("dd", "\304\221\303\243"));
        assert(fs::exists(custom));
    }

    // Corrupt files load as empty, never crash.
    {
        const auto dir = make_case_dir(root, "corrupt");
        MacroStore store(dir);
        const auto file = dir / "macros.json";
        write_file(file, "this is not json");
        assert(store.load().empty());
        write_file(file, "{\"macros\": [{\"trigger\": \"vn\"");
        assert(store.load().empty());
        write_file(file, "{\"macros\": {}}");
        assert(store.load().empty());
        write_file(file, "{\"macros\": [1, 2]}");
        assert(store.load().empty());
        write_file(file, "{\"macros\": [{\"trigger\": \"vn\", \"replacement\": \"x\"}, garbage]}");
        assert(store.load().empty());
        write_file(file, "");
        assert(store.load().empty());
    }

    // Validation: non-empty fields, ASCII printable triggers, length caps.
    {
        MacroStore store(make_case_dir(root, "validation"));
        assert(!store.add("", "replacement"));
        assert(!store.add("   ", "replacement"));
        assert(!store.add("\t\n", "replacement"));
        assert(!store.add("vn", ""));
        assert(!store.add("vn", " \t\n "));
        assert(!store.add("a b", "x"));
        assert(!store.add("ti\341\272\277ng", "x"));
        assert(!store.add(std::string(65, 'a'), "x"));
        assert(store.add(std::string(64, 'a'), "x"));
        assert(!store.add("ok", std::string(MacroStore::kMaxReplacementLength + 1, 'x')));
        assert(store.load().size() == 1);
    }

    // Normalization: triggers trimmed + lowercased, replacements trimmed.
    {
        MacroStore store(make_case_dir(root, "normalize"));
        assert(store.add("  VN  ", "Vi\341\273\207t Nam"));
        auto loaded = store.load();
        assert(loaded.size() == 1);
        assert(loaded.front().trigger == "vn");
        assert(store.add("sg", "  S\303\240i G\303\262n  "));
        loaded = store.load();
        assert(loaded.size() == 2);
        assert(loaded.front().trigger == "sg");
        assert(loaded.front().replacement == "S\303\240i G\303\262n");
    }

    // Duplicates: case-insensitive merge updates the replacement in place.
    {
        MacroStore store(make_case_dir(root, "duplicates"));
        assert(store.add("aa", "first"));
        assert(store.add("bb", "second"));
        assert(store.add("AA", "merged"));
        const auto loaded = store.load();
        assert(loaded.size() == 2);
        assert(loaded[0].trigger == "bb" && loaded[0].replacement == "second");
        assert(loaded[1].trigger == "aa" && loaded[1].replacement == "merged");
    }

    // Update: renames a trigger, merges into an existing duplicate, rejects
    // invalid input without touching the table.
    {
        MacroStore store(make_case_dir(root, "update"));
        assert(store.add("aa", "first"));
        assert(store.add("bb", "second"));
        assert(!store.update("zz", "cc", "nope"));
        assert(!store.update("aa", "bad trigger", "x"));
        assert(store.load().size() == 2);
        assert(store.update("aa", "cc", "third"));
        auto loaded = store.load();
        assert(loaded.size() == 2);
        assert(loaded[0].trigger == "cc" && loaded[0].replacement == "third");
        assert(loaded[1].trigger == "bb" && loaded[1].replacement == "second");
        assert(store.update("cc", "bb", "merged"));
        loaded = store.load();
        assert(loaded.size() == 1);
        assert(loaded[0].trigger == "bb" && loaded[0].replacement == "merged");
    }

    // Remove: normalized lookup, false when absent.
    {
        MacroStore store(make_case_dir(root, "remove"));
        assert(store.add("aa", "1"));
        assert(store.add("bb", "2"));
        assert(!store.remove("zz"));
        assert(store.remove("AA"));
        const auto loaded = store.load();
        assert(loaded.size() == 1 && loaded[0].trigger == "bb");
    }

    // entries_as_pairs: consumption format for MacroEngine::reload, order kept.
    {
        MacroStore store(make_case_dir(root, "pairs"));
        assert(store.add("vn", "Vi\341\273\207t Nam"));
        assert(store.add("ko", "kh\303\264ng"));
        const auto pairs = store.entries_as_pairs();
        assert(pairs.size() == 2);
        assert((pairs[0] == std::pair<std::string, std::string>{"ko", "kh\303\264ng"}));
        assert((pairs[1] == std::pair<std::string, std::string>{"vn", "Vi\341\273\207t Nam"}));
    }

    // JSON escaping round-trips quotes, backslashes and newlines.
    {
        MacroStore store(make_case_dir(root, "escaping"));
        const std::string tricky = "line1\nline2 \"quoted\" \\slash\\\ttab";
        assert(store.add("qq", tricky));
        const auto loaded = store.load();
        assert(loaded.size() == 1);
        assert(loaded[0].replacement == tricky);
    }

    // load() sanitizes hand-edited files: normalizes, drops invalid rows,
    // keeps the first occurrence per trigger.
    {
        const auto dir = make_case_dir(root, "sanitize");
        MacroStore store(dir);
        write_file(dir / "macros.json",
                   "{\"schemaVersion\": 1, \"macros\": ["
                   "{\"trigger\": \"VN\", \"replacement\": \"first\"},"
                   "{\"trigger\": \"vn\", \"replacement\": \"second\"},"
                   "{\"trigger\": \"\", \"replacement\": \"skip\"},"
                   "{\"trigger\": \"h\303\240 n\341\271\231i\", \"replacement\": \"skip\"}"
                   "]}");
        const auto loaded = store.load();
        assert(loaded.size() == 1);
        assert(loaded[0].trigger == "vn");
        assert(loaded[0].replacement == "first");
    }

    // save() writes sanitized entries only.
    {
        MacroStore store(make_case_dir(root, "save-normalize"));
        assert(store.save({{"  UP ", "x"}, {"up", "y"}, {"", "z"}, {"ok", "w"}}));
        const auto loaded = store.load();
        assert(loaded.size() == 2);
        assert(loaded[0].trigger == "up" && loaded[0].replacement == "x");
        assert(loaded[1].trigger == "ok" && loaded[1].replacement == "w");
    }

    return 0;
}
