#include "TrayIpcHandler.h"
namespace skey::windows {
IpcResponse TrayIpcHandler::operator()(const IpcRequest& request) const {
    IpcResponse response{.protocol_version = kIpcProtocolVersion, .request_id = request.request_id};
    if (request.protocol_version != kIpcProtocolVersion) { response.error_code = "protocol_version"; return response; }
    if (request.method == kGetStatus) {
        response.ok = true;
        response.payload = runtime_.vietnamese_enabled() ? "{\"isVietnamese\":true}" : "{\"isVietnamese\":false}";
    } else if (request.method == kSetLanguage) {
        const bool desired = request.payload == "true";
        if (runtime_.vietnamese_enabled() != desired) runtime_.toggle_language();
        response.ok = runtime_.vietnamese_enabled() == desired;
    } else if (request.method == kRestartService) {
        response.ok = runtime_.running();
    } else response.error_code = "unknown_method";
    return response;
}
}
