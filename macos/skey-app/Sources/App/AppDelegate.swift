import AppKit
import Foundation

// MARK: - AppDelegate

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        skeyLog("Application launching...")
        AppCoordinator.shared.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.stop()
        skeyLog("Application terminating...")
    }
}
