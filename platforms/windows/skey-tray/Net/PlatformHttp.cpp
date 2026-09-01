#include "PlatformHttp.h"

#include <string>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#endif

namespace skey::windows {

#ifdef _WIN32

namespace {

std::wstring to_wide(const std::string& utf8) {
    if (utf8.empty()) return {};
    const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
    std::wstring out(static_cast<std::size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), out.data(), length);
    return out;
}

struct ParsedUrl {
    std::wstring host;
    std::wstring path;
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    DWORD flags = WINHTTP_FLAG_SECURE;
    bool secure = true;
};

bool parse_url(const std::string& url, ParsedUrl& out) {
    URL_COMPONENTS parts{};
    parts.dwStructSize = sizeof(parts);
    wchar_t host[256]{};
    wchar_t path[2048]{};
    parts.lpszHostName = host;
    parts.dwHostNameLength = 256;
    parts.lpszUrlPath = path;
    parts.dwUrlPathLength = 2048;

    const std::wstring wide = to_wide(url);
    if (WinHttpCrackUrl(wide.c_str(), static_cast<DWORD>(wide.size()), 0, &parts) == FALSE) {
        return false;
    }
    out.host.assign(host, parts.dwHostNameLength);
    out.path.assign(path, parts.dwUrlPathLength);
    if (out.path.empty()) out.path = L"/";
    out.secure = parts.nScheme == INTERNET_SCHEME_HTTPS;
    out.port = parts.nPort != 0 ? parts.nPort
                                : (out.secure ? INTERNET_DEFAULT_HTTPS_PORT : INTERNET_DEFAULT_HTTP_PORT);
    out.flags = out.secure ? WINHTTP_FLAG_SECURE : 0;
    return true;
}

bool request(const std::string& method, const std::string& url, const std::string& extra_headers,
             const std::string& body, std::string& response) {
    ParsedUrl parsed;
    if (!parse_url(url, parsed)) return false;

    const HINTERNET session = WinHttpOpen(L"SKey-Windows/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                          WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (session == nullptr) return false;

    bool ok = false;
    HINTERNET connection = nullptr;
    HINTERNET handle = nullptr;
    do {
        DWORD timeout_ms = 10000;
        WinHttpSetTimeouts(session, timeout_ms, timeout_ms, timeout_ms, 15000);

        connection = WinHttpConnect(session, parsed.host.c_str(), parsed.port, 0);
        if (connection == nullptr) break;

        const std::wstring wide_method = to_wide(method);
        handle = WinHttpOpenRequest(connection, wide_method.c_str(), parsed.path.c_str(), nullptr,
                                    WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, parsed.flags);
        if (handle == nullptr) break;

        if (!extra_headers.empty()) {
            const std::wstring wide_headers = to_wide(extra_headers);
            WinHttpAddRequestHeaders(handle, wide_headers.c_str(),
                                     static_cast<DWORD>(wide_headers.size()),
                                     WINHTTP_ADDREQ_FLAG_ADD);
        }

        const DWORD body_size = static_cast<DWORD>(body.size());
        if (WinHttpSendRequest(handle, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                               body.empty() ? WINHTTP_NO_REQUEST_DATA
                                            : const_cast<char*>(body.data()),
                               body_size, body_size, 0) == FALSE) {
            break;
        }
        if (WinHttpReceiveResponse(handle, nullptr) == FALSE) break;

        DWORD status = 0;
        DWORD status_size = sizeof(status);
        if (WinHttpQueryHeaders(handle, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
                                WINHTTP_NO_HEADER_INDEX) == FALSE) {
            break;
        }
        if (status < 200 || status >= 300) break;

        std::string accumulated;
        for (;;) {
            DWORD available = 0;
            if (WinHttpQueryDataAvailable(handle, &available) == FALSE || available == 0) break;
            std::vector<char> chunk(available);
            DWORD read = 0;
            if (WinHttpReadData(handle, chunk.data(), available, &read) == FALSE || read == 0) break;
            accumulated.append(chunk.data(), read);
        }
        response = std::move(accumulated);
        ok = true;
    } while (false);

    if (handle != nullptr) WinHttpCloseHandle(handle);
    if (connection != nullptr) WinHttpCloseHandle(connection);
    WinHttpCloseHandle(session);
    return ok;
}

} // namespace

TranslatorService::HttpFn make_platform_http() {
    return [](const std::string& method, const std::string& url, const std::string& extra_headers,
              const std::string& body, std::string& response) {
        return request(method, url, extra_headers, body, response);
    };
}

#else

TranslatorService::HttpFn make_platform_http() { return nullptr; }

#endif

} // namespace skey::windows
