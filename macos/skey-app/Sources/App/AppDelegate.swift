import AppKit
import Foundation

// MARK: - AppDelegate

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        skeyLog("Application launching...")
        setupStandardMainMenu()
        AppCoordinator.shared.start()

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.skey.openSettings"),
            object: nil,
            queue: .main
        ) { _ in
            SettingsWindowController.shared.showSettings()
        }

        if CommandLine.arguments.contains("--settings") || CommandLine.arguments.contains("-s") {
            SettingsWindowController.shared.showSettings()
        }

        // Silent background update check after launch (non-intrusive)
        if AppSettings.shared.general.checkUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                UpdateCheckerService.shared.checkForUpdates(isManual: false)
            }
        }
    }

    private func setupStandardMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "SKey")
        appMenu.addItem(withTitle: L10n("menu.app.settings"), action: #selector(openSettingsMenuAction), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L10n("menu.app.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L10n("menu.app.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L10n("menu.app.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: L10n("menu.edit.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n("menu.edit.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: L10n("menu.edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n("menu.edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n("menu.edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n("menu.edit.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsMenuAction() {
        SettingsWindowController.shared.showSettings()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.showSettings()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.stop()
        skeyLog("Application terminating...")
    }
}
