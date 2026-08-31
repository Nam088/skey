#include "../Shared/Translator/TranslatorService.h"

#include <cassert>
#include <string>
#include <vector>

using namespace skey::windows;

namespace {

struct FakeHttp {
    // One canned response per call, in order. ok=false simulates transport
    // failure; body is returned as the response.
    struct Canned {
        bool ok;
        std::string body;
    };
    std::vector<Canned> canned;
    std::vector<std::string> methods;
    std::vector<std::string> urls;
    std::vector<std::string> headers;
    std::vector<std::string> bodies;

    TranslatorService::HttpFn fn() {
        return [this](const std::string& method, const std::string& url,
                      const std::string& extra_headers, const std::string& body,
                      std::string& response) {
            methods.push_back(method);
            urls.push_back(url);
            headers.push_back(extra_headers);
            bodies.push_back(body);
            const std::size_t index = methods.size() - 1;
            if (index >= canned.size()) return false;
            if (!canned[index].ok) return false;
            response = canned[index].body;
            return true;
        };
    }
};

TranslatorEngine engine(std::string provider, bool enabled = true, std::string key = "") {
    return TranslatorEngine{std::move(provider), enabled, std::move(key)};
}

} // namespace

int main() {
    // --- url_encode ---
    {
        assert(TranslatorService::url_encode("hello") == "hello");
        assert(TranslatorService::url_encode("a b") == "a%20b");
        assert(TranslatorService::url_encode("A-z_0.~") == "A-z_0.~");
        assert(TranslatorService::url_encode("&=") == "%26%3D");
        // đ = U+0111 = C4 91
        assert(TranslatorService::url_encode("\xC4\x91") == "%C4%91");
    }

    // --- json_escape ---
    {
        assert(TranslatorService::json_escape("say \"hi\"") == "say \\\"hi\\\"");
        assert(TranslatorService::json_escape("a\\b") == "a\\\\b");
        assert(TranslatorService::json_escape("a\nb\tc\r") == "a\\nb\\tc\\r");
        assert(TranslatorService::json_escape("\x01") == "\\u0001");
        assert(TranslatorService::json_escape("ti\xE1\xBA\xBFng") == "ti\xE1\xBA\xBFng");
    }

    // --- html_decode ---
    {
        assert(TranslatorService::html_decode("&amp;lt;") == "&lt;");
        assert(TranslatorService::html_decode("&quot;a&quot;") == "\"a\"");
        assert(TranslatorService::html_decode("a&nbsp;b") == "a b");
        assert(TranslatorService::html_decode("&#7845;n") == "\xE1\xBA\xA5n");   // ấ = U+1EA5
        assert(TranslatorService::html_decode("&#x1EBF;") == "\xE1\xBA\xBF");    // ế
        assert(TranslatorService::html_decode("&unknown;") == "&unknown;");
        assert(TranslatorService::html_decode("a & b") == "a & b");
        assert(TranslatorService::html_decode("") == "");
    }

    // --- google_url ---
    {
        TranslateParams p;
        p.text = "hello world";
        p.source = "auto";
        p.target = "vi";
        assert(TranslatorService::google_url(p) ==
               "https://translate.google.com/m?sl=auto&tl=vi&q=hello%20world");
    }

    // --- parse_google_html ---
    {
        std::string out;
        const std::string html =
            "<html><body><div dir=\"ltr\" class=\"result-container\">"
            "Xin ch&#224;o</div><script>x</script></body></html>";
        assert(TranslatorService::parse_google_html(html, out));
        assert(out == "Xin ch\xC3\xA0o");

        // Inner tags are stripped, entities decoded.
        const std::string tagged =
            "class=\"result-container\"><b>a&amp;b</b></div>";
        assert(TranslatorService::parse_google_html(tagged, out));
        assert(out == "a&b");

        assert(!TranslatorService::parse_google_html("no marker here", out));
        assert(!TranslatorService::parse_google_html("class=\"result-container\"></div>", out));
    }

    // --- DeepL ---
    {
        assert(TranslatorService::deepl_url("abc:fx") == "https://api-free.deepl.com/v2/translate");
        assert(TranslatorService::deepl_url("abc") == "https://api.deepl.com/v2/translate");

        TranslateParams p;
        p.text = "hi";
        p.source = "auto";
        p.target = "vi";
        assert(TranslatorService::deepl_body(p) == "text=hi&target_lang=VI");
        p.source = "en";
        assert(TranslatorService::deepl_body(p) == "text=hi&target_lang=VI&source_lang=EN");

        std::string out;
        const std::string body =
            "{\"translations\":[{\"detected_source_language\":\"EN\",\"text\":\"Xin ch\\u00e0o\"}]}";
        assert(TranslatorService::parse_deepl_json(body, out));
        assert(out == "Xin ch\xC3\xA0o");
        assert(!TranslatorService::parse_deepl_json("{}", out));
    }

    // --- Gemini ---
    {
        assert(TranslatorService::gemini_url("k") ==
               "https://generativelanguage.googleapis.com/v1beta/models/"
               "gemini-2.0-flash:generateContent?key=k");

        TranslateParams p;
        p.text = "hi";
        p.source = "auto";
        p.target = "vi";
        const std::string body = TranslatorService::gemini_body(p);
        assert(body.find("\"contents\":[{\"parts\":[{\"text\":\"") != std::string::npos);
        assert(body.find("to vi") != std::string::npos);
        assert(body.find("\"temperature\":0.2") != std::string::npos);

        std::string out;
        const std::string reply =
            "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Xin ch\\u00e0o\"}],\"role\":\"model\"}}]}";
        assert(TranslatorService::parse_gemini_json(reply, out));
        assert(out == "Xin ch\xC3\xA0o");
        assert(!TranslatorService::parse_gemini_json("{\"promptFeedback\":{}}", out));
    }

    // --- Groq ---
    {
        TranslateParams p;
        p.text = "hi";
        p.target = "vi";
        const std::string body = TranslatorService::groq_body(p);
        assert(body.find("\"model\":\"llama-3.3-70b-versatile\"") != std::string::npos);
        assert(body.find("\"role\":\"system\"") != std::string::npos);

        std::string out;
        const std::string reply =
            "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Xin ch\\u00e0o\"}}]}";
        assert(TranslatorService::parse_groq_json(reply, out));
        assert(out == "Xin ch\xC3\xA0o");
        assert(!TranslatorService::parse_groq_json("{\"error\":{}}", out));
    }

    // --- extract_json_string: escapes and surrogate pairs ---
    {
        std::string out;
        assert(TranslatorService::extract_json_string("{\"a\":\"x\\n\\t\\\"q\\\"\"}", "a", 0, out));
        assert(out == "x\n\t\"q\"");

        // U+1F600 via surrogate pair.
        assert(TranslatorService::extract_json_string("{\"a\":\"\\ud83d\\ude00\"}", "a", 0, out));
        assert(out == "\xF0\x9F\x98\x80");

        // Missing key, or key whose value is not a string.
        assert(!TranslatorService::extract_json_string("{\"a\":1}", "a", 0, out));
        assert(!TranslatorService::extract_json_string("{\"a\":\"x\"}", "b", 0, out));

        // Search resumes from `from`; skips earlier occurrences.
        const std::string json = "{\"text\":\"first\",\"nested\":{\"text\":\"second\"}}";
        assert(TranslatorService::extract_json_string(json, "text", json.find("\"nested\""), out));
        assert(out == "second");
    }

    const TranslateParams params{"hello", "auto", "vi"};

    // --- Cascade: first engine fails, second succeeds ---
    {
        FakeHttp http;
        http.canned = {
            {false, {}},  // deepl transport fails
            {true, "class=\"result-container\">Xin ch&#224;o</div>"},
        };
        TranslatorService service(http.fn());
        const std::vector<TranslatorEngine> engines{engine("deepl", true, "key"), engine("google")};
        const auto result = service.translate(params, engines);
        assert(result.ok);
        assert(result.text == "Xin ch\xC3\xA0o");
        assert(result.engine == "google");
        assert(http.methods.size() == 2);
        assert(http.methods[0] == "POST");
        assert(http.methods[1] == "GET");
    }

    // --- Cascade: first success stops the chain ---
    {
        FakeHttp http;
        http.canned = {{true, "{\"translations\":[{\"text\":\"Ch\\u00e0o\"}]}"}
        };
        TranslatorService service(http.fn());
        const std::vector<TranslatorEngine> engines{engine("deepl", true, "key"), engine("google")};
        const auto result = service.translate(params, engines);
        assert(result.ok);
        assert(result.engine == "deepl");
        assert(http.methods.size() == 1);
        assert(http.headers[0].find("DeepL-Auth-Key key") != std::string::npos);
    }

    // --- Key-required engines without a key are skipped ---
    {
        FakeHttp http;
        http.canned = {{true, "class=\"result-container\">ok</div>"}};
        TranslatorService service(http.fn());
        const std::vector<TranslatorEngine> engines{
            engine("deepl"), engine("gemini"), engine("groq"), engine("google")};
        const auto result = service.translate(params, engines);
        assert(result.ok);
        assert(result.engine == "google");
        assert(http.urls.size() == 1);
        assert(http.urls[0].find("translate.google.com") != std::string::npos);
    }

    // --- Disabled engines are skipped ---
    {
        FakeHttp http;
        http.canned = {{true, "class=\"result-container\">ok</div>"}};
        TranslatorService service(http.fn());
        const std::vector<TranslatorEngine> engines{engine("google", false), engine("google")};
        const auto result = service.translate(params, engines);
        assert(result.ok);
        assert(http.urls.size() == 1);
    }

    // --- Empty text short-circuits ---
    {
        FakeHttp http;
        TranslatorService service(http.fn());
        const auto result = service.translate({"", "auto", "vi"}, {engine("google")});
        assert(!result.ok);
        assert(!result.error.empty());
        assert(http.methods.empty());
    }

    // --- Google fallback retry when the configured cascade fails ---
    {
        FakeHttp http;
        http.canned = {
            {false, {}},  // configured google fails
            {true, "class=\"result-container\">fallback</div>"},  // retry succeeds
        };
        TranslatorService service(http.fn());
        const auto result = service.translate(params, {engine("google")});
        assert(result.ok);
        assert(result.text == "fallback");
        assert(http.urls.size() == 2);
    }

    // --- Everything fails: error surfaces ---
    {
        FakeHttp http;
        http.canned = {{false, {}}, {false, {}}};
        TranslatorService service(http.fn());
        const auto result = service.translate(params, {engine("google")});
        assert(!result.ok);
        assert(!result.error.empty());
        assert(http.urls.size() == 2);
    }

    return 0;
}
