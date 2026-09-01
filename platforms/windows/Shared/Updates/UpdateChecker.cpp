#include "UpdateChecker.h"

#include <fstream>
#include <utility>

#include "../Translator/TranslatorService.h"

namespace skey::windows {

namespace {

bool json_flag_true(const std::string& json, const std::string& key) {
    const auto anchor = json.find("\"" + key + "\"");
    if (anchor == std::string::npos) return false;
    auto at = anchor + key.size() + 2;
    while (at < json.size() && (json[at] == ' ' || json[at] == '\t' ||
                                json[at] == '\n' || json[at] == '\r')) {
        ++at;
    }
    if (at >= json.size() || json[at] != ':') return false;
    ++at;
    while (at < json.size() && (json[at] == ' ' || json[at] == '\t' ||
                                json[at] == '\n' || json[at] == '\r')) {
        ++at;
    }
    return json.compare(at, 4, "true") == 0;
}

// Walks back from `anchor` to the '{' opening the JSON object that contains
// it (balanced, so nested objects like "author" are skipped).
std::size_t object_start(const std::string& json, std::size_t anchor) {
    std::size_t at = anchor;
    int depth = 0;
    while (at > 0) {
        --at;
        if (json[at] == '}') {
            ++depth;
        } else if (json[at] == '{') {
            if (depth == 0) return at;
            --depth;
        }
    }
    return 0;
}

std::size_t object_end(const std::string& json, std::size_t start) {
    int depth = 0;
    for (std::size_t at = start; at < json.size(); ++at) {
        if (json[at] == '{') {
            ++depth;
        } else if (json[at] == '}') {
            --depth;
            if (depth == 0) return at + 1;
        }
    }
    return json.size();
}

std::string read_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return {};
    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    return content;
}

} // namespace

UpdateChecker::UpdateChecker(HttpFn http) : http_(std::move(http)) {}

bool UpdateChecker::parse_semver(const std::string& text, std::array<int, 3>& out) {
    out = {0, 0, 0};
    std::size_t at = 0;
    for (int part = 0; part < 3; ++part) {
        if (part > 0) {
            if (at >= text.size() || text[at] != '.') return false;
            ++at;
        }
        int value = 0;
        bool any = false;
        while (at < text.size() && text[at] >= '0' && text[at] <= '9') {
            value = value * 10 + (text[at] - '0');
            ++at;
            any = true;
        }
        if (!any) return false;
        out[static_cast<std::size_t>(part)] = value;
    }
    // Trailing suffixes ("0.2.0-beta1") are ignored.
    return true;
}

int UpdateChecker::compare_semver(const std::array<int, 3>& a, const std::array<int, 3>& b) {
    for (std::size_t i = 0; i < 3; ++i) {
        if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
    }
    return 0;
}

bool UpdateChecker::newer_than(const std::string& candidate, const std::string& current) {
    std::array<int, 3> a{};
    std::array<int, 3> b{};
    if (!parse_semver(candidate, a) || !parse_semver(current, b)) return false;
    return compare_semver(a, b) > 0;
}

UpdateInfo UpdateChecker::pick_release(const std::string& releases_json,
                                       const std::string& current_version) {
    const std::string prefix = kTagPrefix;
    const std::string marker = "\"tag_name\"";
    std::size_t at = 0;
    while (true) {
        const auto anchor = releases_json.find(marker, at);
        if (anchor == std::string::npos) break;
        at = anchor + marker.size();

        std::string tag;
        if (!TranslatorService::extract_json_string(releases_json, "tag_name", anchor, tag)) {
            break;
        }
        if (tag.size() <= prefix.size() || tag.compare(0, prefix.size(), prefix) != 0) {
            continue;
        }
        const std::string version = tag.substr(prefix.size());
        if (!newer_than(version, current_version)) continue;

        const std::size_t start = object_start(releases_json, anchor);
        const std::size_t end = object_end(releases_json, start);
        const std::string object = releases_json.substr(start, end - start);
        if (json_flag_true(object, "draft") || json_flag_true(object, "prerelease")) {
            continue;
        }

        UpdateInfo info;
        info.available = true;
        info.version = version;
        TranslatorService::extract_json_string(object, "html_url", 0, info.release_url);

        // Prefer the MSI installer, then any .exe, else leave empty.
        const std::string asset_marker = "\"browser_download_url\"";
        std::size_t asset_at = 0;
        while (true) {
            const auto asset_anchor = object.find(asset_marker, asset_at);
            if (asset_anchor == std::string::npos) break;
            asset_at = asset_anchor + asset_marker.size();
            std::string url;
            if (!TranslatorService::extract_json_string(object, "browser_download_url",
                                                        asset_anchor, url)) {
                break;
            }
            const bool msi = url.size() >= 4 && url.compare(url.size() - 4, 4, ".msi") == 0;
            const bool exe = url.size() >= 4 && url.compare(url.size() - 4, 4, ".exe") == 0;
            if (msi) {
                info.asset_url = url;
                break;
            }
            if (exe && info.asset_url.empty()) info.asset_url = url;
        }
        return info;
    }
    return {};
}

UpdateInfo UpdateChecker::check(const std::string& current_version) const {
    if (!http_) return {};
    std::string response;
    const bool ok = http_("GET", kApiUrl,
                          "User-Agent: SKey-Windows\r\n"
                          "Accept: application/vnd.github+json\r\n",
                          "", response);
    if (!ok) return {};
    return pick_release(response, current_version);
}

UpdateState UpdateChecker::load_state(const std::filesystem::path& path) {
    UpdateState state;
    const std::string json = read_file(path);
    if (json.empty()) return state;

    const auto anchor = json.find("\"last_check_ms\"");
    if (anchor != std::string::npos) {
        auto at = json.find(':', anchor);
        if (at != std::string::npos) {
            ++at;
            while (at < json.size() && (json[at] == ' ' || json[at] == '\t' ||
                                        json[at] == '\n' || json[at] == '\r')) {
                ++at;
            }
            std::uint64_t value = 0;
            while (at < json.size() && json[at] >= '0' && json[at] <= '9') {
                value = value * 10 + static_cast<std::uint64_t>(json[at] - '0');
                ++at;
            }
            state.last_check_ms = value;
        }
    }
    TranslatorService::extract_json_string(json, "dismissed_version", 0, state.dismissed_version);
    return state;
}

void UpdateChecker::save_state(const std::filesystem::path& path, const UpdateState& state) {
    std::error_code ec;
    std::filesystem::create_directories(path.parent_path(), ec);
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (!file) return;
    file << "{\n  \"last_check_ms\": " << state.last_check_ms
         << ",\n  \"dismissed_version\": \"" << TranslatorService::json_escape(state.dismissed_version)
         << "\"\n}\n";
}

} // namespace skey::windows
