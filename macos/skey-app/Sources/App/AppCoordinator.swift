import AppKit
import Foundation

// MARK: - AppCoordinator

public final class AppCoordinator {
    public static let shared = AppCoordinator()

    // Registered features
    public let keyboardFeature  = KeyboardFeature()
    public let clipboardFeature = ClipboardFeature.shared

    private(set) var features: [Feature] = []
    private var permissionTimer: Timer?

    private init() {
        features = [
            keyboardFeature,
            clipboardFeature,
        ]
    }

    public func start() {
        skeyLog("AppCoordinator starting features...")

        // 1. Setup Status Bar Manager with all features
        StatusBarManager.shared.configure(with: features)
        StatusBarManager.shared.onLeftClickToggle = { [weak self] in
            self?.keyboardFeature.toggleLanguage()
        }

        // 2. Connect Keyboard Feature status icon callback
        keyboardFeature.onStatusIconChange = { isVietnamese in
            StatusBarManager.shared.updateStatusIcon(isVietnamese: isVietnamese)
        }
        StatusBarManager.shared.updateStatusIcon(isVietnamese: AppSettings.shared.keyboard.isVietnamese)

        // 3. Start all registered features
        features.forEach { $0.start() }

        // 4. App Focus Monitoring: resets composing buffer & triggers Smart App Switch
        AppFocusObserver.shared.startObserving { [weak self] bundleID in
            self?.keyboardFeature.handleAppFocusChanged(to: bundleID)
        }

        // 5. Sync Launch at Login system service
        LaunchAtLoginService.syncOnLaunch()

        // 6. Check permissions & start polling if needed
        checkAndRequestPermissions()
    }

    public func stop() {
        skeyLog("AppCoordinator stopping...")
        permissionTimer?.invalidate()
        permissionTimer = nil
        AppFocusObserver.shared.stopObserving()
        features.forEach { $0.stop() }
    }

    private func checkAndRequestPermissions() {
        if PermissionsService.shared.checkPermissions(prompt: false) {
            skeyLog("All permissions verified.")
        } else {
            skeyLog("Prompting permissions...")
            _ = PermissionsService.shared.checkPermissions(prompt: true)
            PermissionsService.shared.openInputMonitoringSettings()
            PermissionsService.shared.openAccessibilitySettings()

            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if PermissionsService.shared.checkPermissions(prompt: false) {
                    timer.invalidate()
                    self?.permissionTimer = nil
                    self?.keyboardFeature.start()
                    skeyLog("Permissions granted dynamically!")
                }
            }
        }
    }
}
