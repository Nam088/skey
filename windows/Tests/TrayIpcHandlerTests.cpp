#include "../skey-tray/TrayIpcHandler.h"

#include <cassert>

using namespace skey::windows;

int main() {
    TrayRuntime runtime;
    assert(runtime.start());
    TrayIpcHandler handler(runtime);
    IpcRequest status{.request_id = "1", .method = kGetStatus};
    const auto first = handler(status);
    assert(first.ok && first.payload.find("true") != std::string::npos);
    IpcRequest set{.request_id = "2", .method = kSetLanguage, .payload = "false"};
    assert(handler(set).ok && !runtime.vietnamese_enabled());
    IpcRequest bad{.protocol_version = 99, .request_id = "3", .method = kGetStatus};
    assert(!handler(bad).ok);

    IpcRequest status_off{.request_id = "4", .method = kGetStatus};
    const auto off_status = handler(status_off);
    assert(off_status.ok && off_status.payload.find("false") != std::string::npos);

    IpcRequest set_same{.request_id = "5", .method = kSetLanguage, .payload = "false"};
    assert(handler(set_same).ok && !runtime.vietnamese_enabled());

    IpcRequest restart{.request_id = "6", .method = kRestartService};
    assert(handler(restart).ok);

    IpcRequest unknown{.request_id = "7", .method = "nonexistent_method"};
    const auto unk = handler(unknown);
    assert(!unk.ok && unk.error_code == "unknown_method");

    runtime.stop();
    return 0;
}
