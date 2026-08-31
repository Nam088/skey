import AppKit
import Foundation

// MARK: - Navigation & Selection Logic

public extension ClipboardHistoryViewModel {

    func selectByIndex(_ index: Int, asPlainText: Bool = false) {
        guard items.indices.contains(index) else { return }
        onSelect([items[index]], asPlainText)
    }

    func selectOnHover(id: UUID, hovering: Bool) {
        autoPreviewTask?.cancel()

        // When mouse leaves an item, clear selection only if this item was selected
        if !hovering {
            if selectedItemID == id {
                selectedItemID = nil
            }
            return
        }

        if selectedItemID != id {
            selectedItemID = id
        }

        guard settings.openPreviewAutomatically else { return }
        if isPreviewOpen { return }

        let delay = max(100, settings.previewDelayMilliseconds)
        autoPreviewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self,
                  self.selectedItemID == id,
                  !self.isPreviewOpen,
                  self.items.contains(where: { $0.id == id }) else { return }
            self.togglePreview()
        }
    }

    func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        hoverThrottler.cancel()
        pasteStackSelected = false
        let currentIndex = items.firstIndex { $0.id == selectedItemID } ?? 0
        let newIndex = max(0, min(items.count - 1, currentIndex + delta))
        selectedItemID = items[newIndex].id
        scrollTargetID = items[newIndex].id
    }

    func moveToFirst() {
        guard let first = items.first else { return }
        hoverThrottler.cancel()
        pasteStackSelected = false
        selectedItemID = first.id
        scrollTargetID = first.id
    }

    func moveToLast() {
        guard let last = items.last else { return }
        hoverThrottler.cancel()
        pasteStackSelected = false
        selectedItemID = last.id
        scrollTargetID = last.id
    }

    func extendSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        hoverThrottler.cancel()
        pasteStackSelected = false
        if stackedItemIDs.isEmpty {
            if let current = selectedItemID ?? items.first?.id {
                stackedItemIDs = [current]
            }
        }
        let anchorIndex = items.firstIndex { $0.id == selectedItemID } ?? 0
        let newIndex = max(0, min(items.count - 1, anchorIndex + delta))
        let newID = items[newIndex].id
        if !stackedItemIDs.contains(newID) {
            stackedItemIDs.append(newID)
        }
        selectedItemID = newID
        scrollTargetID = newID
    }

    func confirmSelection(asPlainText: Bool = false) {
        if !stackedItemIDs.isEmpty {
            onSelect(pasteStackItems, asPlainText)
            return
        }
        guard let item = activePreviewItem else { return }
        onSelect([item], asPlainText)
    }

    func selectRow(_ item: ClipboardItem, asPlainText: Bool = false) {
        pasteStackSelected = false
        if !stackedItemIDs.isEmpty {
            onSelect(pasteStackItems, asPlainText)
        } else {
            onSelect([item], asPlainText)
        }
    }
}
