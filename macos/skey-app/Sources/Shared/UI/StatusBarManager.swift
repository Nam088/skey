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
        updateStatusIcon(isVietnamese: AppSettings.shared.keyboard.isVietnamese)
    }

    // MARK: - Elegant & Grouped Menu Builder

    public func rebuildMenu() {
        menu = NSMenu()

        // 1. Group: Keyboard Features (Tiếng Việt, Kiểu gõ, Bảng mã, Tùy chọn)
        for feature in features {
            let featureItems = feature.buildMenuItems()
            guard !featureItems.isEmpty else { continue }
            for item in featureItems {
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 2. Group: Snippets / Macro Shortcut Item
        let snippetsItem = NSMenuItem(
            title: L10n("settings.tab.snippets"),
            action: #selector(openSnippetsSettings),
            keyEquivalent: ""
        )
        snippetsItem.target = self
        menu.addItem(snippetsItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Group: Settings & Tools Submenu
        let settingsItem = NSMenuItem(
            title: L10n(.clipboardSettings),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let toolsSubmenu = NSMenu()

        // Language in Tools
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let langItem = NSMenuItem(
                title: lang.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            langItem.target = self
            langItem.representedObject = lang
            langItem.state = (LocalizationService.shared.currentLanguage == lang) ? NSControl.StateValue.on : NSControl.StateValue.off
            langMenu.addItem(langItem)
        }
        let langSubmenuItem = NSMenuItem(title: L10n(.languageMenu), action: nil, keyEquivalent: "")
        langSubmenuItem.submenu = langMenu
        toolsSubmenu.addItem(langSubmenuItem)

        toolsSubmenu.addItem(NSMenuItem.separator())

        // Permissions
        let openInputMonItem = NSMenuItem(
            title: L10n(.inputMonitoringSetting),
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        openInputMonItem.target = self
        toolsSubmenu.addItem(openInputMonItem)

        let openAXItem = NSMenuItem(
            title: L10n(.accessibilitySetting),
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAXItem.target = self
        toolsSubmenu.addItem(openAXItem)

        toolsSubmenu.addItem(NSMenuItem.separator())

        // Screen & Keyboard Cleaner
        let cleanerItem = NSMenuItem(
            title: L10n("tools.action.cleaner"),
            action: #selector(startKeyboardCleaner),
            keyEquivalent: ""
        )
        cleanerItem.target = self
        toolsSubmenu.addItem(cleanerItem)

        #if DEBUG
        toolsSubmenu.addItem(NSMenuItem.separator())

        // Logs (Dev Only)
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
        #endif

        let toolsItem = NSMenuItem(title: L10n("tools.menu.title"), action: nil, keyEquivalent: "")
        toolsItem.submenu = toolsSubmenu
        menu.addItem(toolsItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Group: Quit SKey
        let quitItem = NSMenuItem(title: L10n(.quitApp), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Menu Actions

    @objc private func startKeyboardCleaner() {
        Task { @MainActor in
            KeyboardCleanerController.shared.startCleaning()
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings(tab: .keyboard)
    }

    @objc private func openSnippetsSettings() {
        SettingsWindowController.shared.showSettings(tab: .snippets)
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

    // MARK: - Beautiful 3D Block / Keycap Status Bar Icon (V / E)

    public func updateStatusIcon(isVietnamese: Bool) {
        guard let button = statusItem?.button else { return }

        let iconText = isVietnamese ? "V" : "E"
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // 1. Draw rounded keycap tile box
        let borderRect = NSRect(x: 1.0, y: 1.0, width: size.width - 2.0, height: size.height - 2.0)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 4.0, yRadius: 4.0)

        NSColor.black.setStroke()
        borderPath.lineWidth = 1.3
        borderPath.stroke()

        // 2. Draw "V" or "E" letter centered with bold weight
        let font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = (iconText as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2.0,
            y: (size.height - textSize.height) / 2.0 - 0.5,
            width: textSize.width,
            height: textSize.height
        )
        (iconText as NSString).draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = true

        button.attributedTitle = NSAttributedString(string: "")
        button.image = image
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
