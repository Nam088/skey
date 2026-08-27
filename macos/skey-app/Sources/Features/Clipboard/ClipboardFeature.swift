import AppKit
import Foundation

// MARK: - ClipboardFeature

/// Feature module providing Maccy-like Clipboard History management
public final class ClipboardFeature: NSObject, Feature {
    public let id = "com.nam088.skey.feature.clipboard"
    public var name: String { L10n(.clipboardMenu) }

    public var isEnabled: Bool { PreferencesService.shared.isClipboardEnabled }

    private let monitor = ClipboardMonitor.shared

    public override init() {
        super.init()
    }

    // MARK: - Feature Lifecycle

    public func start() {
        guard isEnabled else { return }
        monitor.start()
        skeyLog("ClipboardFeature started", category: .clipboard)
    }

    public func stop() {
        monitor.stop()
        skeyLog("ClipboardFeature stopped", category: .clipboard)
    }

    // MARK: - Menu Builder

    public func buildMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        let clipboardMenu = NSMenu()

        let recentItems = monitor.history
        if recentItems.isEmpty {
            let emptyItem = NSMenuItem(title: L10n(.clipboardEmpty), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            clipboardMenu.addItem(emptyItem)
        } else {
            for (index, item) in recentItems.prefix(15).enumerated() {
                let shortcutKey = (index < 9) ? "\(index + 1)" : ""
                let title = "\(index + 1). \(item.previewText)"
                let menuItem = NSMenuItem(title: title, action: #selector(pasteItemClicked(_:)), keyEquivalent: shortcutKey)
                menuItem.target = self
                menuItem.representedObject = item.text
                clipboardMenu.addItem(menuItem)
            }

            clipboardMenu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: L10n(.clearClipboard), action: #selector(clearHistoryClicked), keyEquivalent: "")
            clearItem.target = self
            clipboardMenu.addItem(clearItem)
        }

        let mainItem = NSMenuItem(title: L10n(.clipboardMenu), action: nil, keyEquivalent: "")
        mainItem.submenu = clipboardMenu
        items.append(mainItem)

        return items
    }

    // MARK: - Actions

    @objc private func pasteItemClicked(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let item = ClipboardItem(text: text)
        monitor.copyToPasteboard(item)
        skeyLog("Pasted clipboard item to pasteboard: '\(item.previewText)'", category: .clipboard)
    }

    @objc private func clearHistoryClicked() {
        monitor.clearHistory()
        skeyLog("Clipboard history cleared", category: .clipboard)
    }
}
