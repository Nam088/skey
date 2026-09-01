#include "../Shared/Clipboard/ClipboardHistoryStore.h"
#include "../Shared/Clipboard/ClipboardText.h"

#include <cassert>
#include <cstdio>
#include <filesystem>
#include <iostream>

using namespace skey::windows;

namespace {

std::filesystem::path temp_file(const char* name) {
    auto path = std::filesystem::temp_directory_path() / name;
    std::error_code ec;
    std::filesystem::remove(path, ec);
    return path;
}

void test_fold() {
    assert(ClipboardText::fold("Hello") == "hello");
    assert(ClipboardText::fold("Ti\xE1\xBA\xBFng Vi\xE1\xBB\x87t") == "tieng viet");  // Tiếng Việt
    assert(ClipboardText::fold("\xC4\x91\xC6\xB0\xE1\xBB\x9Dng") == "duong");         // đường
    assert(ClipboardText::fold("\xC4\x90\xC3\x81NH") == "danh");                      // ĐÁNH
    assert(ClipboardText::fold("abc 123") == "abc 123");
    assert(ClipboardText::fold("") == "");
}

void test_sha256() {
    assert(ClipboardText::sha256_hex("") ==
           "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    assert(ClipboardText::sha256_hex("abc") ==
           "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    // 56-byte boundary case (padding edge).
    assert(ClipboardText::sha256_hex(std::string(56, 'a')).size() == 64);
    assert(ClipboardText::sha256_hex(std::string(64, 'a')).size() == 64);
}

void test_rank() {
    const std::string text = "Ti\xE1\xBA\xBFng Vi\xE1\xBB\x87t";  // Tiếng Việt
    const std::string folded = ClipboardText::fold(text);

    assert(ClipboardText::rank(text, folded, "Ti\xE1\xBA\xBFng") == 2000000);
    assert(ClipboardText::rank(text, folded, "tieng") == 1000000);
    assert(ClipboardText::rank(text, folded, "tv") == 0);   // subsequence
    assert(ClipboardText::rank(text, folded, "zzz") == -1); // no match

    // Exact-case substring beats folded substring.
    assert(ClipboardText::rank(text, folded, "Ti") == 2000000);
    assert(ClipboardText::rank(text, folded, "vi") < 1000000 &&
           ClipboardText::rank(text, folded, "vi") >= 0);
}

void test_store_dedup_and_order() {
    const auto path = temp_file("skey_clip_history_dedup.json");
    ClipboardHistoryStore store(path);

    store.add_text("first", 1000);
    store.add_text("second", 2000);
    assert(store.items().size() == 2);
    assert(store.items()[0].text == "second");  // newest first
    assert(store.items()[0].copy_count == 1);

    // Re-copying bumps recency and copyCount instead of duplicating.
    store.add_text("first", 3000);
    assert(store.items().size() == 2);
    assert(store.items()[0].text == "first");
    assert(store.items()[0].copy_count == 2);
    assert(store.items()[0].last_copied_at == 3000);
    assert(store.items()[0].first_copied_at == 1000);
}

void test_store_trim_respects_pins() {
    const auto path = temp_file("skey_clip_history_trim.json");
    ClipboardHistoryStore store(path);
    store.set_max_items(2);

    store.add_text("a", 1);
    store.add_text("b", 2);
    store.add_text("c", 3);
    assert(store.items().size() == 2);
    assert(store.items()[0].text == "c");
    assert(store.items()[1].text == "b");

    // Pinned items survive trimming even beyond the limit.
    store.set_pinned(1, true);  // pin "b"
    store.add_text("d", 4);
    store.add_text("e", 5);
    assert(store.items().size() == 3);  // 2 unpinned + 1 pinned
    bool pinned_present = false;
    for (const auto& item : store.items()) {
        if (item.pinned) {
            pinned_present = true;
            assert(item.text == "b");
        }
    }
    assert(pinned_present);

    store.clear_unpinned();
    assert(store.items().size() == 1);
    assert(store.items()[0].pinned);
}

void test_store_roundtrip() {
    const auto path = temp_file("skey_clip_history_roundtrip.json");
    {
        ClipboardHistoryStore store(path);
        store.add_text("xin ch\xC3\xA0 \xC4\x91i\nnext line", 100);
        store.add_text("\"quoted\" \\ backslash\ttab", 200);
        store.set_pinned(0, true);
        assert(store.save());
    }
    ClipboardHistoryStore reloaded(path);
    assert(reloaded.load());
    assert(reloaded.items().size() == 2);
    assert(reloaded.items()[0].text == "\"quoted\" \\ backslash\ttab");
    assert(reloaded.items()[0].pinned);
    assert(reloaded.items()[1].text == "xin ch\xC3\xA0 \xC4\x91i\nnext line");
    assert(!reloaded.items()[1].pinned);
    assert(reloaded.items()[1].folded == ClipboardText::fold(reloaded.items()[1].text));
}

void test_store_search() {
    const auto path = temp_file("skey_clip_history_search.json");
    ClipboardHistoryStore store(path);
    store.add_text("hello world", 1);
    store.add_text("Ti\xE1\xBA\xBFng Vi\xE1\xBB\x87t th\xC3\xA2n y\xC3\xAAu", 2);  // Tiếng Việt thân yêu
    store.add_text("unrelated", 3);

    const auto results = store.search("tieng viet");
    assert(results.size() == 1);
    assert(store.items()[results[0]].text == "Ti\xE1\xBA\xBFng Vi\xE1\xBB\x87t th\xC3\xA2n y\xC3\xAAu");

    const auto all = store.search("");
    assert(all.size() == 3);

    const auto none = store.search("zzz-no-match");
    assert(none.empty());

    // Exact-case match outranks folded match.
    store.add_text("tieng viet lowercase", 4);
    const auto ordered = store.search("tieng viet");
    assert(ordered.size() == 2);
    assert(store.items()[ordered[0]].text == "tieng viet lowercase");
}

} // namespace

int main() {
    test_fold();
    test_sha256();
    test_rank();
    test_store_dedup_and_order();
    test_store_trim_respects_pins();
    test_store_roundtrip();
    test_store_search();
    std::cout << "CLIPBOARD_HISTORY_TESTS_OK\n";
    return 0;
}
