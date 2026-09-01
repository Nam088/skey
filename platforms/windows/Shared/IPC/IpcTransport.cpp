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

bool IpcServer::serve_once(const std::string& endpoint, const std::function<bool()>& alive) const {
#ifdef _WIN32
    if (!handler_) return false;
    HANDLE pipe = CreateNamedPipeA(endpoint.c_str(), PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
                                   PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT, 1, 65536, 65536,
                                   3000, nullptr);
    if (pipe == INVALID_HANDLE_VALUE) return false;

    // Overlapped accept: ConnectNamedPipe would otherwise block indefinitely,
    // which makes the server thread unjoinable during shutdown.
    OVERLAPPED overlapped{};
    overlapped.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    bool connected = false;
    bool pending = false;
    if (ConnectNamedPipe(pipe, &overlapped) != FALSE) {
        connected = true;
    } else {
        const DWORD error = GetLastError();
        if (error == ERROR_PIPE_CONNECTED) {
            connected = true;
        } else if (error == ERROR_IO_PENDING) {
            pending = true;
            while (true) {
                const DWORD rc = WaitForSingleObject(overlapped.hEvent, 250);
                if (rc == WAIT_OBJECT_0) { connected = true; break; }
                if (rc != WAIT_TIMEOUT) break;
                if (alive && !alive()) break;
            }
        }
    }
    if (!connected) {
        if (pending) {
            CancelIoEx(pipe, nullptr);
            WaitForSingleObject(overlapped.hEvent, 1000);  // aborted IRP completion
        }
        DisconnectNamedPipe(pipe);
        CloseHandle(pipe);
        CloseHandle(overlapped.hEvent);
        return false;
    }
    CloseHandle(overlapped.hEvent);

    char buffer[65536]{}; DWORD read = 0, written = 0; IpcRequest request;
    const bool received = ReadFile(pipe, buffer, sizeof(buffer) - 1, &read, nullptr) && IpcCodec::decode_request(std::string_view(buffer, read), request);
    IpcResponse response = received ? handler_(request) : IpcResponse{}; const auto wire = IpcCodec::encode(response);
    const bool sent = received && WriteFile(pipe, wire.data(), static_cast<DWORD>(wire.size()), &written, nullptr); DisconnectNamedPipe(pipe); CloseHandle(pipe); return sent;
#else
    (void)endpoint; (void)alive; return false;
#endif
}
} // namespace skey::windows
