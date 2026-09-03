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
        // Only update icon and tooltip, don't rebuild entire menu
        updateStatusIcon(isVietnamese: AppSettings.shared.keyboard.isVietnamese)
    }

    // MARK: - Modern & Compact Menu Builder with SF Symbols Icons

    public func rebuildMenu() {
        menu = NSMenu()

        // 1. Group: Keyboard Features (from registered features)
        for feature in features {
            let featureItems = feature.buildMenuItems()
            guard !featureItems.isEmpty else { continue }
            for item in featureItems {
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 2. Group: Quick Actions
        let snippetsItem = NSMenuItem(
            title: L10n("settings.tab.snippets"),
            action: #selector(openSnippetsSettings),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "pencil.and.outline", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            snippetsItem.image = image
        }
        snippetsItem.target = self
        menu.addItem(snippetsItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Group: Settings & Tools
        let settingsItem = NSMenuItem(
            title: L10n("menu.app.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        if let image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            settingsItem.image = image
        }
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Language selector (moved to main menu)
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let langItem = NSMenuItem(
                title: lang.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            if let image = NSImage(systemSymbolName: lang == .vietnamese ? "flag.circle.fill" : "globe.asia.australia.fill", accessibilityDescription: nil) {
                image.size = NSSize(width: 16, height: 16)
                langItem.image = image
            }
            langItem.target = self
            langItem.representedObject = lang
            langItem.state = (LocalizationService.shared.currentLanguage == lang) ? NSControl.StateValue.on : NSControl.StateValue.off
            langMenu.addItem(langItem)
        }
        let langSubmenuItem = NSMenuItem(title: L10n(.languageMenu), action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            langSubmenuItem.image = image
        }
        langSubmenuItem.submenu = langMenu
        menu.addItem(langSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let toolsSubmenu = NSMenu()

        // Permissions with icons
        let openInputMonItem = NSMenuItem(
            title: L10n(.inputMonitoringSetting),
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            openInputMonItem.image = image
        }
        openInputMonItem.target = self
        toolsSubmenu.addItem(openInputMonItem)

        let openAXItem = NSMenuItem(
            title: L10n(.accessibilitySetting),
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "accessibility.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            openAXItem.image = image
        }
        openAXItem.target = self
        toolsSubmenu.addItem(openAXItem)

        toolsSubmenu.addItem(NSMenuItem.separator())

        // Cleaner with icon
        let cleanerItem = NSMenuItem(
            title: L10n("tools.action.cleaner"),
            action: #selector(startKeyboardCleaner),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            cleanerItem.image = image
        }
        cleanerItem.target = self
        toolsSubmenu.addItem(cleanerItem)

        #if DEBUG
        toolsSubmenu.addItem(NSMenuItem.separator())

        // Logs (Dev Only) with icons
        let openLogItem = NSMenuItem(
            title: L10n(.openLogFile),
            action: #selector(openLogFile),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            openLogItem.image = image
        }
        openLogItem.target = self
        toolsSubmenu.addItem(openLogItem)

        let clearLogItem = NSMenuItem(
            title: L10n(.clearLogs),
            action: #selector(clearLogs),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "eraser.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            clearLogItem.image = image
        }
        clearLogItem.target = self
        toolsSubmenu.addItem(clearLogItem)
        #endif

        let toolsItem = NSMenuItem(title: L10n("tools.menu.title"), action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            toolsItem.image = image
        }
        toolsItem.submenu = toolsSubmenu
        menu.addItem(toolsItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Group: Quit with icon
        let quitItem = NSMenuItem(title: L10n(.quitApp), action: #selector(quitApp), keyEquivalent: "q")
        if let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            quitItem.image = image
        }
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
            // Rebuild menu on right-click to refresh dynamic content (language state, etc.)
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
