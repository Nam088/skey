import AppKit
import Foundation

// MARK: - StatusBarManager

public final class StatusBarManager: NSObject {
    public static let shared = StatusBarManager()

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var features: [Feature] = []

    public var onLeftClickToggle: (() -> Void)?

    private override init() {
        super.init()
        setupStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .skeyLanguageDidChange,
            object: nil
        )
    }

    public func configure(with features: [Feature]) {
        self.features = features
        rebuildMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func languageDidChange() {
        rebuildMenu()
        updateStatusIcon(isVietnamese: PreferencesService.shared.isVietnamese)
    }

    public func rebuildMenu() {
        menu = NSMenu()

        // 1. Add items from all registered features
        for (index, feature) in features.enumerated() {
            let featureItems = feature.buildMenuItems()
            guard !featureItems.isEmpty else { continue }

            for item in featureItems {
                menu.addItem(item)
            }

            if index < features.count - 1 {
                menu.addItem(NSMenuItem.separator())
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 2. Language Switcher Submenu
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let langItem = NSMenuItem(
                title: lang.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            langItem.target = self
            langItem.representedObject = lang
            langItem.state = (LocalizationService.shared.currentLanguage == lang) ? .on : .off
            langMenu.addItem(langItem)
        }
        let langMenuItem = NSMenuItem(title: L10n(.languageMenu), action: nil, keyEquivalent: "")
        langMenuItem.submenu = langMenu
        menu.addItem(langMenuItem)

        // 3. System Permissions Submenu
        let permSubmenu = NSMenu()
        let openInputMonItem = NSMenuItem(
            title: L10n(.inputMonitoringSetting),
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        openInputMonItem.target = self
        permSubmenu.addItem(openInputMonItem)

        let openAXItem = NSMenuItem(
            title: L10n(.accessibilitySetting),
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAXItem.target = self
        permSubmenu.addItem(openAXItem)

        let permItem = NSMenuItem(title: L10n(.systemPermissions), action: nil, keyEquivalent: "")
        permItem.submenu = permSubmenu
        menu.addItem(permItem)

        // 4. Utilities / Logging Submenu
        let toolsSubmenu = NSMenu()
        let openLogItem = NSMenuItem(
            title: L10n(.openLogFile),
            action: #selector(openLogFile),
            keyEquivalent: ""
        )
        openLogItem.target = self
        toolsSubmenu.addItem(openLogItem)

        let clearLogItem = NSMenuItem(
            title: L10n(.clearLogs),
            action: #selector(clearLogs),
            keyEquivalent: ""
        )
        clearLogItem.target = self
        toolsSubmenu.addItem(clearLogItem)

        let toolsItem = NSMenuItem(title: L10n(.toolsAndLogs), action: nil, keyEquivalent: "")
        toolsItem.submenu = toolsSubmenu
        menu.addItem(toolsItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Quit Item
        let quitItem = NSMenuItem(title: L10n(.quitApp), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? AppLanguage else { return }
        LocalizationService.shared.currentLanguage = lang
    }

    @objc private func openLogFile() {
        let path = SKeyLogger.shared.logFilePath
        if !FileManager.default.fileExists(atPath: path) {
            _ = try? "".write(toFile: path, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func clearLogs() {
        LogStore.shared.clear()
        try? FileManager.default.removeItem(atPath: SKeyLogger.shared.logFilePath)
        skeyLog("Logs cleared by user", category: .ui)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            rebuildMenu()
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
        } else {
            onLeftClickToggle?()
        }
    }

    public func updateStatusIcon(isVietnamese: Bool) {
        guard let button = statusItem.button else { return }

        let text = isVietnamese ? "V" : "E"
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .black)
        let color = isVietnamese ? NSColor.systemBlue : NSColor.secondaryLabelColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
        button.toolTip = isVietnamese ? L10n(.tooltipVietnamese) : L10n(.tooltipEnglish)
    }

    @objc private func openInputMonitoringSettings() {
        PermissionsService.shared.openInputMonitoringSettings()
    }

    @objc private func openAccessibilitySettings() {
        PermissionsService.shared.openAccessibilitySettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
