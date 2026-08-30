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
    runtime.stop();
    return 0;
}
