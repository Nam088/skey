#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "../Contracts/SettingsModel.h"

namespace skey::windows {

struct TranslateParams {
    std::string text;
    std::string source = "auto";  // "auto" = detect
    std::string target = "vi";
};

struct TranslateOutcome {
    bool ok = false;
    std::string text;
    std::string engine;   // provider that produced the result
    std::string error;    // set when !ok
    std::uint64_t latency_ms = 0;
};

// Provider cascade mirroring macOS TranslationService: engines run in the
// user's configured order, key-required engines without a key are skipped,
// any failure falls through to the next engine, and Google is retried once
// as a universal fallback when everything fails.
class TranslatorService {
public:
    // HTTP transport: returns true on a 2xx response body. Injectable so the
    // cascade and parsers are unit-testable without a network.
    using HttpFn = std::function<bool(const std::string& method,
                                      const std::string& url,
                                      const std::string& extra_headers,
                                      const std::string& body,
                                      std::string& response)>;

    explicit TranslatorService(HttpFn http = {});

    TranslateOutcome translate(const TranslateParams& params,
                               const std::vector<TranslatorEngine>& engines) const;

    void set_http(HttpFn http) { http_ = std::move(http); }

    // --- Pure helpers (unit-tested, platform-independent) ---
    static std::string url_encode(const std::string& utf8);
    static std::string json_escape(const std::string& utf8);
    static std::string html_decode(const std::string& html);

    static std::string google_url(const TranslateParams& params);
    static bool parse_google_html(const std::string& html, std::string& out);

    static std::string deepl_url(const std::string& api_key);
    static std::string deepl_body(const TranslateParams& params);
    static bool parse_deepl_json(const std::string& body, std::string& out);

    static std::string gemini_url(const std::string& api_key);
    static std::string llm_prompt(const TranslateParams& params);
    static std::string gemini_body(const TranslateParams& params);
    static bool parse_gemini_json(const std::string& body, std::string& out);

    static std::string groq_body(const TranslateParams& params);
    static bool parse_groq_json(const std::string& body, std::string& out);

    // Extracts the string value of `key` in `json`, searching from `from`.
    static bool extract_json_string(const std::string& json, const std::string& key,
                                    std::size_t from, std::string& out);

private:
    HttpFn http_;
};

} // namespace skey::windows
