import AppKit
import Foundation

// MARK: - ClipboardMonitor

public final class ClipboardMonitor {
    public static let shared = ClipboardMonitor()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?

    public private(set) var history: [ClipboardItem] = []
    public var onHistoryUpdated: (() -> Void)?

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        // Timer tolerance allows macOS power management to coalesce wakeups,
        // avoiding waking the CPU out of deep C-states and preserving battery life.
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func clearHistory() {
        // Keep pinned items
        history = history.filter { $0.isPinned }
        onHistoryUpdated?()
    }

    public func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let newString = pasteboard.string(forType: .string), !newString.isEmpty else {
            return
        }

        // Avoid duplicate at the top of history
        if let first = history.first, first.text == newString {
            return
        }

        // Remove if existing in history to bubble up
        history.removeAll(where: { $0.text == newString && !$0.isPinned })

        let newItem = ClipboardItem(text: newString)
        history.insert(newItem, at: 0)

        // Limit size
        let limit = PreferencesService.shared.clipboardLimit
        if history.count > limit {
            history = Array(history.prefix(limit))
        }

        skeyLog("Clipboard captured: '\(newItem.previewText)'")
        onHistoryUpdated?()
    }
}
