#include "../Shared/Updates/UpdateChecker.h"

#include <array>
#include <cassert>
#include <cstdio>
#include <filesystem>
#include <string>
#include <vector>

using namespace skey::windows;

namespace {

const char* kSampleReleases = R"json([
  {
    "url": "https://api.github.com/repos/Nam088/skey/releases/2",
    "html_url": "https://github.com/Nam088/skey/releases/tag/win-v0.3.0",
    "id": 2,
    "author": {"login": "Nam088", "id": 1, "html_url": "https://github.com/Nam088"},
    "tag_name": "win-v0.3.0",
    "name": "SKey 0.3.0 (Windows)",
    "draft": false,
    "prerelease": false,
    "assets": [
      {"name": "SKey-0.3.0.zip", "browser_download_url": "https://github.com/x/SKey-0.3.0.zip"},
      {"name": "SKey-0.3.0.msi", "browser_download_url": "https://github.com/x/SKey-0.3.0.msi"}
    ],
    "body": "notes with {braces} and stuff"
  },
  {
    "url": "https://api.github.com/repos/Nam088/skey/releases/1",
    "html_url": "https://github.com/Nam088/skey/releases/tag/win-v0.1.0",
    "id": 1,
    "author": {"login": "Nam088", "id": 1, "html_url": "https://github.com/Nam088"},
    "tag_name": "win-v0.1.0",
    "draft": false,
    "prerelease": false,
    "assets": [
      {"name": "SKey-0.1.0.msi", "browser_download_url": "https://github.com/x/SKey-0.1.0.msi"}
    ],
    "body": ""
  }
])json";

struct FakeHttp {
    bool ok = true;
    std::string body;
    std::string url;
    std::string headers;

    UpdateChecker::HttpFn fn() {
        return [this](const std::string&, const std::string& u, const std::string& h,
                      const std::string&, std::string& response) {
            url = u;
            headers = h;
            if (!ok) return false;
            response = body;
            return true;
        };
    }
};

} // namespace

int main() {
    // --- parse_semver / compare ---
    {
        std::array<int, 3> v{};
        assert(UpdateChecker::parse_semver("0.1.0", v) && v[0] == 0 && v[1] == 1 && v[2] == 0);
        assert(UpdateChecker::parse_semver("1.2.3", v) && v[0] == 1 && v[1] == 2 && v[2] == 3);
        assert(UpdateChecker::parse_semver("0.2.0-beta1", v) && v[1] == 2);
        assert(!UpdateChecker::parse_semver("1.2", v));
        assert(!UpdateChecker::parse_semver("", v));
        assert(!UpdateChecker::parse_semver("v1.2.3", v));

        assert(UpdateChecker::newer_than("0.2.0", "0.1.0"));
        assert(UpdateChecker::newer_than("0.1.1", "0.1.0"));
        assert(UpdateChecker::newer_than("1.0.0", "0.9.9"));
        assert(!UpdateChecker::newer_than("0.1.0", "0.1.0"));
        assert(!UpdateChecker::newer_than("0.0.9", "0.1.0"));
        assert(!UpdateChecker::newer_than("bogus", "0.1.0"));
    }

    // --- pick_release: newest newer release wins, MSI preferred ---
    {
        const auto info = UpdateChecker::pick_release(kSampleReleases, "0.1.0");
        assert(info.available);
        assert(info.version == "0.3.0");
        assert(info.release_url == "https://github.com/Nam088/skey/releases/tag/win-v0.3.0");
        assert(info.asset_url == "https://github.com/x/SKey-0.3.0.msi");
    }

    // --- Already current: nothing newer ---
    {
        const auto info = UpdateChecker::pick_release(kSampleReleases, "0.3.0");
        assert(!info.available);
    }

    // --- Non-windows tags are ignored ---
    {
        const std::string json = R"json([
            {"tag_name": "mac-v9.9.9", "html_url": "h", "draft": false, "prerelease": false, "assets": []},
            {"tag_name": "v9.9.9", "html_url": "h", "draft": false, "prerelease": false, "assets": []}
        ])json";
        const auto info = UpdateChecker::pick_release(json, "0.1.0");
        assert(!info.available);
    }

    // --- Drafts and prereleases are skipped ---
    {
        const std::string json = R"json([
            {"tag_name": "win-v2.0.0", "draft": true, "prerelease": false, "assets": []},
            {"tag_name": "win-v1.9.0", "draft": false, "prerelease": true, "assets": []},
            {"tag_name": "win-v1.8.0", "draft": false, "prerelease": false,
             "html_url": "stable", "assets": [
                {"name": "a.exe", "browser_download_url": "https://x/a.exe"}]}
        ])json";
        const auto info = UpdateChecker::pick_release(json, "0.1.0");
        assert(info.available);
        assert(info.version == "1.8.0");
        assert(info.release_url == "stable");
        assert(info.asset_url == "https://x/a.exe");
    }

    // --- check() over injected HTTP ---
    {
        FakeHttp http;
        http.body = kSampleReleases;
        UpdateChecker checker(http.fn());
        const auto info = checker.check("0.1.0");
        assert(info.available);
        assert(http.url == UpdateChecker::kApiUrl);
        assert(http.headers.find("User-Agent") != std::string::npos);

        FakeHttp down;
        down.ok = false;
        UpdateChecker offline(down.fn());
        assert(!offline.check("0.1.0").available);

        UpdateChecker no_transport;
        assert(!no_transport.check("0.1.0").available);
    }

    // --- State round-trip ---
    {
        const auto path = std::filesystem::temp_directory_path() / "skey_update_state_test.json";
        UpdateState state;
        state.last_check_ms = 1730000000000ULL;
        state.dismissed_version = "0.3.0";
        UpdateChecker::save_state(path, state);

        const auto loaded = UpdateChecker::load_state(path);
        assert(loaded.last_check_ms == 1730000000000ULL);
        assert(loaded.dismissed_version == "0.3.0");

        const auto missing = UpdateChecker::load_state(
            std::filesystem::temp_directory_path() / "skey_no_such_state.json");
        assert(missing.last_check_ms == 0);
        assert(missing.dismissed_version.empty());

        std::error_code ec;
        std::filesystem::remove(path, ec);
    }

    return 0;
}
