#include "../Shared/Contracts/IpcCodec.h"
#include "../Shared/IPC/IpcTransport.h"
#include "../skey-tray/TrayRuntime.h"

#include <cassert>
#include <iostream>

int main() {
    using namespace skey::windows;
    IpcRequest request{1, "id\t1", "setSettings", "line1\nline2", 2500};
    const auto wire = IpcCodec::encode(request);
    IpcRequest decoded;
    assert(IpcCodec::decode_request(wire, decoded));
    assert(decoded.request_id == request.request_id && decoded.payload == request.payload);

    IpcResponse response{1, "id", true, {}, "ok"};
    IpcResponse decoded_response;
    assert(IpcCodec::decode_response(IpcCodec::encode(response), decoded_response));
    assert(decoded_response.ok && decoded_response.payload == "ok");
    IpcRequest malformed;
    assert(!IpcCodec::decode_request("REQ\t1\tbad%ZZ\tmethod\t1\tpayload\n", malformed));
    IpcResponse malformed_response;
    assert(!IpcCodec::decode_response("RES\t1\tid\t2\t\tpayload\n", malformed_response));

    TrayRuntime tray;
    assert(tray.start());
    assert(!tray.start());
    assert(tray.toggle_language() && !tray.vietnamese_enabled());
    tray.stop();
    assert(!tray.running());
    TrayRuntime ipc_runtime;
    assert(ipc_runtime.start_ipc([](const IpcRequest& req) {
        return IpcResponse{1, req.request_id, true, {}, "ack"};
    }));
    ipc_runtime.stop();
    assert(!ipc_runtime.running());
    std::cout << "IPC_TRAY_TESTS_OK\n";
}
