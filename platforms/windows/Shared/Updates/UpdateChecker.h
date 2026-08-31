#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <string>

namespace skey::windows {

inline constexpr const char* kAppVersion = "0.1.0";

struct UpdateInfo {
    bool available = false;
    std::string version;      // "0.2.0" (tag minus the win-v prefix)
    std::string release_url;  // html_url of the release
    std::string asset_url;    // preferred installer download (.msi)
};

struct UpdateState {
    std::uint64_t last_check_ms = 0;
    std::string dismissed_version;
};

// GitHub release watcher mirroring macOS UpdateChecker: looks for win-v*
// tags on the releases endpoint, compares semver against the running build
// and surfaces the newest one. HTTP is injectable for tests.
class UpdateChecker {
public:
    using HttpFn = std::function<bool(const std::string& method,
                                      const std::string& url,
                                      const std::string& extra_headers,
                                      const std::string& body,
                                      std::string& response)>;

    explicit UpdateChecker(HttpFn http = {});

    UpdateInfo check(const std::string& current_version) const;

    // --- Pure helpers (unit-tested) ---
    static bool parse_semver(const std::string& text, std::array<int, 3>& out);
    static int compare_semver(const std::array<int, 3>& a, const std::array<int, 3>& b);
    static bool newer_than(const std::string& candidate, const std::string& current);
    static UpdateInfo pick_release(const std::string& releases_json,
                                   const std::string& current_version);
    static UpdateState load_state(const std::filesystem::path& path);
    static void save_state(const std::filesystem::path& path, const UpdateState& state);

    static constexpr const char* kApiUrl =
        "https://api.github.com/repos/Nam088/skey/releases";
    static constexpr const char* kTagPrefix = "win-v";

private:
    HttpFn http_;
};

} // namespace skey::windows
