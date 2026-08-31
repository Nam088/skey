#include "../skey-settings/Features/Clipboard/Services/ClipboardService.h"
#include "../skey-settings/Features/Clipboard/Models/ClipboardItem.h"

#include <cassert>
#include <iostream>

using namespace skey::windows;

int main() {
    ClipboardService service;

    assert(service.items().empty());

    service.add({1, "Hello", false, false});
    service.add({2, "World", false, false});
    assert(service.items().size() == 2);
    assert(service.items()[0].text == "World");
    assert(service.items()[1].text == "Hello");

    service.pin(0);
    assert(service.items()[0].pinned);
    assert(!service.items()[1].pinned);

    service.unpin(0);
    assert(!service.items()[0].pinned);

    service.remove(1);
    assert(service.items().size() == 1);
    assert(service.items()[0].text == "World");

    service.clear();
    assert(service.items().empty());

    service.add({1, "A", false, false});
    service.add({2, "B", false, false});
    service.add({3, "C", false, false});
    service.add({4, "D", false, false});
    service.add({5, "E", false, false});
    assert(service.items().size() == 5);

    service.set_max_items(3);
    assert(service.max_items() == 3);
    assert(service.items().size() == 3);

    service.clear();
    assert(service.items().empty());

    service.add({1, "pinned", true, false});
    service.add({2, "a", false, false});
    service.add({3, "b", false, false});
    service.add({4, "c", false, false});
    service.set_max_items(2);
    assert(service.items().size() == 2);
    auto has_pinned = false;
    for (const auto& item : service.items()) {
        if (item.pinned) has_pinned = true;
    }
    assert(has_pinned);

    std::cout << "CLIPBOARD_SERVICE_TESTS_OK\n";
    return 0;
}
