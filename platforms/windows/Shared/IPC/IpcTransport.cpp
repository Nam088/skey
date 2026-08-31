#include "IpcTransport.h"

#include <utility>

#ifdef _WIN32
#include <windows.h>
#endif

namespace skey::windows {
IpcClient::IpcClient(std::string endpoint) : endpoint_(std::move(endpoint)) {}
IpcServer::IpcServer(IpcHandler handler) : handler_(std::move(handler)) {}

bool IpcClient::call(const IpcRequest& request, IpcResponse& response) const {
#ifdef _WIN32
    HANDLE pipe = CreateFileA(endpoint_.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
    if (pipe == INVALID_HANDLE_VALUE) return false;
    const auto wire = IpcCodec::encode(request); DWORD written = 0, read = 0; char buffer[65536]{};
    const bool sent = WriteFile(pipe, wire.data(), static_cast<DWORD>(wire.size()), &written, nullptr);
    const bool received = sent && ReadFile(pipe, buffer, sizeof(buffer) - 1, &read, nullptr);
    CloseHandle(pipe); return received && IpcCodec::decode_response(std::string_view(buffer, read), response);
#else
    (void)request; (void)response; return false;
#endif
}

bool IpcServer::serve_once(const std::string& endpoint) const {
#ifdef _WIN32
    if (!handler_) return false;
    HANDLE pipe = CreateNamedPipeA(endpoint.c_str(), PIPE_ACCESS_DUPLEX, PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT, 1, 65536, 65536, 3000, nullptr);
    if (pipe == INVALID_HANDLE_VALUE) return false;
    const bool connected = ConnectNamedPipe(pipe, nullptr) != FALSE || GetLastError() == ERROR_PIPE_CONNECTED;
    char buffer[65536]{}; DWORD read = 0, written = 0; IpcRequest request;
    const bool received = connected && ReadFile(pipe, buffer, sizeof(buffer) - 1, &read, nullptr) && IpcCodec::decode_request(std::string_view(buffer, read), request);
    IpcResponse response = received ? handler_(request) : IpcResponse{}; const auto wire = IpcCodec::encode(response);
    const bool sent = received && WriteFile(pipe, wire.data(), static_cast<DWORD>(wire.size()), &written, nullptr); DisconnectNamedPipe(pipe); CloseHandle(pipe); return sent;
#else
    (void)endpoint; return false;
#endif
}
} // namespace skey::windows
