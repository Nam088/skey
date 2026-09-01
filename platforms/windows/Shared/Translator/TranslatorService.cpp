#include "TranslatorService.h"

#include <algorithm>
#include <chrono>
#include <cstdio>

namespace skey::windows {

namespace {

constexpr const char* kGoogleResultMarker = "class=\"result-container\">";

std::uint64_t steady_ms() {
    return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch())
            .count());
}

bool provider_needs_key(const std::string& provider) {
    return provider == "deepl" || provider == "gemini" || provider == "groq";
}

std::string uppercase(std::string value) {
    for (char& c : value) {
        if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 'a' + 'A');
    }
    return value;
}

void append_utf8(std::string& out, char32_t cp) {
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xF0 | (cp >> 18));
        out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
}

} // namespace

TranslatorService::TranslatorService(HttpFn http) : http_(std::move(http)) {}

std::string TranslatorService::url_encode(const std::string& utf8) {
    static const char* hex = "0123456789ABCDEF";
    std::string out;
    out.reserve(utf8.size());
    for (const char raw : utf8) {
        const auto c = static_cast<unsigned char>(raw);
        const bool unreserved = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                                (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~';
        if (unreserved) {
            out += raw;
        } else {
            out += '%';
            out += hex[c >> 4];
            out += hex[c & 0xF];
        }
    }
    return out;
}

std::string TranslatorService::json_escape(const std::string& utf8) {
    std::string out;
    out.reserve(utf8.size());
    for (const char c : utf8) {
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

std::string TranslatorService::html_decode(const std::string& html) {
    std::string out;
    out.reserve(html.size());
    std::size_t i = 0;
    while (i < html.size()) {
        if (html[i] != '&') {
            out += html[i++];
            continue;
        }
        const auto semi = html.find(';', i);
        if (semi == std::string::npos || semi - i > 32) {
            out += html[i++];
            continue;
        }
        const std::string entity = html.substr(i + 1, semi - i - 1);
        bool handled = true;
        if (entity == "amp") out += '&';
        else if (entity == "lt") out += '<';
        else if (entity == "gt") out += '>';
        else if (entity == "quot") out += '"';
        else if (entity == "apos" || entity == "#39") out += '\'';
        else if (entity == "nbsp") out += ' ';
        else if (!entity.empty() && entity[0] == '#') {
            unsigned long code = 0;
            bool numeric = true;
            if (entity.size() > 1 && (entity[1] == 'x' || entity[1] == 'X')) {
                for (std::size_t k = 2; k < entity.size(); ++k) {
                    const char c = entity[k];
                    code *= 16;
                    if (c >= '0' && c <= '9') code += static_cast<unsigned long>(c - '0');
                    else if (c >= 'a' && c <= 'f') code += static_cast<unsigned long>(c - 'a' + 10);
                    else if (c >= 'A' && c <= 'F') code += static_cast<unsigned long>(c - 'A' + 10);
                    else { numeric = false; break; }
                }
            } else {
                for (std::size_t k = 1; k < entity.size(); ++k) {
                    if (entity[k] < '0' || entity[k] > '9') { numeric = false; break; }
                    code = code * 10 + static_cast<unsigned long>(entity[k] - '0');
                }
            }
            if (numeric && code > 0 && code <= 0x10FFFF) {
                append_utf8(out, static_cast<char32_t>(code));
            } else {
                handled = false;
            }
        } else {
            handled = false;
        }
        if (!handled) {
            out += html[i++];
            continue;
        }
        i = semi + 1;
    }
    return out;
}

std::string TranslatorService::google_url(const TranslateParams& params) {
    return "https://translate.google.com/m?sl=" + url_encode(params.source) +
           "&tl=" + url_encode(params.target) + "&q=" + url_encode(params.text);
}

bool TranslatorService::parse_google_html(const std::string& html, std::string& out) {
    const auto start = html.find(kGoogleResultMarker);
    if (start == std::string::npos) return false;
    auto at = start + std::char_traits<char>::length(kGoogleResultMarker);
    const auto close = html.find("</div>", at);
    const std::size_t end = close == std::string::npos ? html.size() : close;
    std::string raw = html.substr(at, end - at);
    std::string without_tags;
    bool in_tag = false;
    for (const char c : raw) {
        if (c == '<') in_tag = true;
        else if (c == '>') in_tag = false;
        else if (!in_tag) without_tags += c;
    }
    out = html_decode(without_tags);
    return !out.empty();
}

std::string TranslatorService::deepl_url(const std::string& api_key) {
    const bool free = api_key.size() >= 3 && api_key.compare(api_key.size() - 3, 3, ":fx") == 0;
    return free ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate";
}

std::string TranslatorService::deepl_body(const TranslateParams& params) {
    std::string body = "text=" + url_encode(params.text) +
                       "&target_lang=" + url_encode(uppercase(params.target));
    if (params.source != "auto") body += "&source_lang=" + url_encode(uppercase(params.source));
    return body;
}

bool TranslatorService::parse_deepl_json(const std::string& body, std::string& out) {
    const auto anchor = body.find("\"translations\"");
    if (anchor == std::string::npos) return false;
    return extract_json_string(body, "text", anchor, out) && !out.empty();
}

std::string TranslatorService::gemini_url(const std::string& api_key) {
    return "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" +
           url_encode(api_key);
}

std::string TranslatorService::llm_prompt(const TranslateParams& params) {
    std::string prompt = "Translate the following text";
    if (params.source != "auto") prompt += " from " + params.source;
    prompt += " to " + params.target +
              ". Output only the translation without quotes or explanations.\n\n" + params.text;
    return prompt;
}

std::string TranslatorService::gemini_body(const TranslateParams& params) {
    return "{\"contents\":[{\"parts\":[{\"text\":\"" + json_escape(llm_prompt(params)) +
           "\"}]}],\"generationConfig\":{\"temperature\":0.2}}";
}

bool TranslatorService::parse_gemini_json(const std::string& body, std::string& out) {
    const auto anchor = body.find("\"candidates\"");
    if (anchor == std::string::npos) return false;
    return extract_json_string(body, "text", anchor, out) && !out.empty();
}

std::string TranslatorService::groq_body(const TranslateParams& params) {
    return "{\"model\":\"llama-3.3-70b-versatile\",\"messages\":["
           "{\"role\":\"system\",\"content\":\"You are a professional translator. Reply with the translation only.\"},"
           "{\"role\":\"user\",\"content\":\"" + json_escape(llm_prompt(params)) + "\"}],"
           "\"temperature\":0.2}";
}

bool TranslatorService::parse_groq_json(const std::string& body, std::string& out) {
    const auto anchor = body.find("\"choices\"");
    if (anchor == std::string::npos) return false;
    return extract_json_string(body, "content", anchor, out) && !out.empty();
}

bool TranslatorService::extract_json_string(const std::string& json, const std::string& key,
                                            std::size_t from, std::string& out) {
    const auto marker = "\"" + key + "\"";
    auto at = json.find(marker, from);
    while (at != std::string::npos) {
        auto cursor = at + marker.size();
        while (cursor < json.size() && (json[cursor] == ' ' || json[cursor] == '\t' ||
                                        json[cursor] == '\n' || json[cursor] == '\r')) {
            ++cursor;
        }
        if (cursor < json.size() && json[cursor] == ':') {
            ++cursor;
            while (cursor < json.size() && (json[cursor] == ' ' || json[cursor] == '\t' ||
                                            json[cursor] == '\n' || json[cursor] == '\r')) {
                ++cursor;
            }
            if (cursor < json.size() && json[cursor] == '"') {
                std::string value;
                ++cursor;
                while (cursor < json.size()) {
                    const char c = json[cursor];
                    if (c == '"') {
                        out = std::move(value);
                        return true;
                    }
                    if (c != '\\') {
                        value += c;
                        ++cursor;
                        continue;
                    }
                    if (cursor + 1 >= json.size()) return false;
                    const char esc = json[cursor + 1];
                    switch (esc) {
                    case 'n': value += '\n'; cursor += 2; break;
                    case 't': value += '\t'; cursor += 2; break;
                    case 'r': value += '\r'; cursor += 2; break;
                    case 'b': value += '\b'; cursor += 2; break;
                    case 'f': value += '\f'; cursor += 2; break;
                    case '"': value += '"'; cursor += 2; break;
                    case '\\': value += '\\'; cursor += 2; break;
                    case '/': value += '/'; cursor += 2; break;
                    case 'u': {
                        if (cursor + 6 > json.size()) return false;
                        unsigned code = 0;
                        bool valid = true;
                        for (int k = 2; k < 6; ++k) {
                            const char h = json[cursor + k];
                            code <<= 4;
                            if (h >= '0' && h <= '9') code += static_cast<unsigned>(h - '0');
                            else if (h >= 'a' && h <= 'f') code += static_cast<unsigned>(h - 'a' + 10);
                            else if (h >= 'A' && h <= 'F') code += static_cast<unsigned>(h - 'A' + 10);
                            else { valid = false; break; }
                        }
                        if (!valid) return false;
                        cursor += 6;
                        char32_t cp = static_cast<char32_t>(code);
                        if (code >= 0xD800 && code <= 0xDBFF && cursor + 6 <= json.size() &&
                            json[cursor] == '\\' && json[cursor + 1] == 'u') {
                            unsigned low = 0;
                            bool low_valid = true;
                            for (int k = 2; k < 6; ++k) {
                                const char h = json[cursor + k];
                                low <<= 4;
                                if (h >= '0' && h <= '9') low += static_cast<unsigned>(h - '0');
                                else if (h >= 'a' && h <= 'f') low += static_cast<unsigned>(h - 'a' + 10);
                                else if (h >= 'A' && h <= 'F') low += static_cast<unsigned>(h - 'A' + 10);
                                else { low_valid = false; break; }
                            }
                            if (low_valid && low >= 0xDC00 && low <= 0xDFFF) {
                                cp = static_cast<char32_t>(0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00));
                                cursor += 6;
                            }
                        }
                        append_utf8(value, cp);
                        break;
                    }
                    default: return false;
                    }
                }
                return false;
            }
        }
        at = json.find(marker, at + marker.size());
    }
    return false;
}

TranslateOutcome TranslatorService::translate(const TranslateParams& params,
                                              const std::vector<TranslatorEngine>& engines) const {
    TranslateOutcome failure;
    failure.error = "no engine available";
    if (params.text.empty() || !http_) return failure;

    const auto attempt = [this](const std::string& provider, const std::string& api_key,
                                const TranslateParams& p, TranslateOutcome& outcome) {
        std::string response;
        bool sent = false;
        if (provider == "google" || provider == "apple") {
            sent = http_("GET", google_url(p),
                         "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)\r\n",
                         "", response);
            outcome.ok = sent && parse_google_html(response, outcome.text);
        } else if (provider == "deepl") {
            sent = http_("POST", deepl_url(api_key),
                         "Authorization: DeepL-Auth-Key " + api_key +
                             "\r\nContent-Type: application/x-www-form-urlencoded\r\n",
                         deepl_body(p), response);
            outcome.ok = sent && parse_deepl_json(response, outcome.text);
        } else if (provider == "gemini") {
            sent = http_("POST", gemini_url(api_key), "Content-Type: application/json\r\n",
                         gemini_body(p), response);
            outcome.ok = sent && parse_gemini_json(response, outcome.text);
        } else if (provider == "groq") {
            sent = http_("POST", "https://api.groq.com/openai/v1/chat/completions",
                         "Authorization: Bearer " + api_key +
                             "\r\nContent-Type: application/json\r\n",
                         groq_body(p), response);
            outcome.ok = sent && parse_groq_json(response, outcome.text);
        } else {
            return;
        }
        outcome.engine = provider == "apple" ? "google" : provider;
        if (!outcome.ok && outcome.error.empty()) outcome.error = provider + " failed";
    };

    bool google_attempted = false;
    for (const auto& engine : engines) {
        if (!engine.enabled) continue;
        if (provider_needs_key(engine.provider) && engine.api_key.empty()) continue;
        if (engine.provider == "google" || engine.provider == "apple") google_attempted = true;

        TranslateOutcome outcome;
        const std::uint64_t started = steady_ms();
        attempt(engine.provider, engine.api_key, params, outcome);
        outcome.latency_ms = steady_ms() - started;
        if (outcome.ok) return outcome;
        failure = outcome;
    }

    // Universal fallback (mirrors macOS): Google needs no key, so it is
    // retried once when the configured cascade produced nothing.
    {
        TranslateOutcome outcome;
        const std::uint64_t started = steady_ms();
        attempt("google", "", params, outcome);
        outcome.latency_ms = steady_ms() - started;
        if (outcome.ok) return outcome;
        if (!google_attempted && failure.error.empty()) failure = outcome;
    }

    return failure;
}

} // namespace skey::windows
