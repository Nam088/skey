import AppKit
import Foundation

// MARK: - Mutations & Item Actions

public extension ClipboardHistoryViewModel {

    func delete(_ item: ClipboardItem) async {
        try? await store.delete(itemID: item.id)
        stackedItemIDs.removeAll { $0 == item.id }
        imageCache.removeObject(forKey: item.id as NSUUID)
        if selectedItemID == item.id {
            selectedItemID = items.first(where: { $0.id != item.id })?.id
        }
        await search(query: searchQuery)
    }

    func clearUnpinned() async {
        try? await store.clearUnpinned()
        stackedItemIDs.removeAll()
        pasteStackSelected = false
        imageCache.removeAllObjects()
        selectedItemID = nil
        await search(query: searchQuery)
    }

    func clearAll() async {
        try? await store.clearAll()
        stackedItemIDs.removeAll()
        pasteStackSelected = false
        imageCache.removeAllObjects()
        selectedItemID = nil
        await search(query: searchQuery)
    }

    func requestClear() {
        if settings.suppressClearAlert {
            Task { await clearUnpinned() }
        } else {
            showClearConfirmation = true
        }
    }

    func requestClearAll() {
        if settings.suppressClearAlert {
            Task { await clearAll() }
        } else {
            showClearAllConfirmation = true
        }
    }

    func togglePin(_ item: ClipboardItem) async {
        try? await store.togglePin(itemID: item.id)
        await search(query: searchQuery)
    }

    func togglePinCurrent() async {
        guard let id = selectedItemID, let item = items.first(where: { $0.id == id }) else { return }
        await togglePin(item)
    }

    func deleteCurrentItem() async {
        if pasteStackSelected {
            removePasteStack()
            return
        }
        guard let id = selectedItemID else { return }
        let idsToDelete = stackedItemIDs.contains(id) ? stackedItemIDs : [id]
        for deleteID in idsToDelete {
            try? await store.delete(itemID: deleteID)
            imageCache.removeObject(forKey: deleteID as NSUUID)
        }
        stackedItemIDs.removeAll()
        if idsToDelete.contains(id) {
            selectedItemID = nil
        }
        await search(query: searchQuery)
    }

    // MARK: - Multi-selection / Paste Stack

    func toggleStack(_ item: ClipboardItem) {
        pasteStackSelected = false
        if let index = stackedItemIDs.firstIndex(of: item.id) {
            stackedItemIDs.remove(at: index)
        } else {
            stackedItemIDs.append(item.id)
        }
    }

    func stackPosition(of item: ClipboardItem) -> Int? {
        guard let index = stackedItemIDs.firstIndex(of: item.id) else { return nil }
        return index + 1
    }

    func selectPasteStack() {
        pasteStackSelected = true
    }

    func removePasteStack() {
        stackedItemIDs.removeAll()
        pasteStackSelected = false
    }

    func openPreferences() {
        onCloseForAction?()
        NSApp.activate(ignoringOtherApps: true)
        openPreferencesHandler?()
    }

    // MARK: - Search Field Editing Chords

    func clearSearchField() {
        searchQuery = ""
    }

    func deleteCharFromSearch() {
        guard !searchQuery.isEmpty else { return }
        searchQuery.removeLast()
    }

    func deleteWordFromSearch() {
        let remaining = searchQuery.split(separator: " ").dropLast().joined(separator: " ")
        searchQuery = remaining.isEmpty ? "" : "\(remaining) "
    }
}
