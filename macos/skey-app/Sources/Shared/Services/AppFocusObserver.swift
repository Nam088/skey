import AppKit
import ApplicationServices
import Foundation
import os.lock

// MARK: - AppFocusObserver

/// Monitors frontmost application activation to trigger smart language switching,
/// buffer resets, and provides thread-safe frontmost PID tracking.
public final class AppFocusObserver {
    public static let shared = AppFocusObserver()

    private var observer: NSObjectProtocol?
    private var lock = os_unfair_lock()

    private var _currentPID: pid_t = 0
    private var _currentBundleID: String?

    public var currentPID: pid_t {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _currentPID
    }

    public var currentBundleID: String? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _currentBundleID
    }

    private init() {
        if let app = NSWorkspace.shared.frontmostApplication {
            updateFrontmostApp(app)
        }
    }

    public func startObserving(onAppChange: @escaping (_ bundleID: String?) -> Void) {
        stopObserving()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.updateFrontmostApp(app)
            onAppChange(app?.bundleIdentifier)
        }
    }

    public func stopObserving() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
    }

    private func updateFrontmostApp(_ app: NSRunningApplication?) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard let app else {
            _currentPID = 0
            _currentBundleID = nil
            return
        }

        _currentPID = app.processIdentifier
        _currentBundleID = app.bundleIdentifier

        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        _ = AXUIElementSetAttributeValue(appElem, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(appElem, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
}
