import AppKit
import Foundation

// MARK: - AppCoordinator

public final class AppCoordinator {
    public static let shared = AppCoordinator()

    // Registered features
    public let keyboardFeature  = KeyboardFeature()
    public let clipboardFeature = ClipboardFeature()

    private(set) var features: [Feature] = []

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
        StatusBarManager.shared.updateStatusIcon(isVietnamese: PreferencesService.shared.isVietnamese)

        // 3. Start all registered features
        features.forEach { $0.start() }

        // 4. App Focus Monitoring: resets composing buffer & triggers Smart App Switch
        AppFocusObserver.shared.startObserving { [weak self] bundleID in
            self?.keyboardFeature.handleAppFocusChanged(to: bundleID)
        }

        // 5. Check permissions & start polling if needed
        checkAndRequestPermissions()
    }

    public func stop() {
        skeyLog("AppCoordinator stopping...")
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

            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if PermissionsService.shared.checkPermissions(prompt: false) {
                    timer.invalidate()
                    self?.keyboardFeature.start()
                    skeyLog("Permissions granted dynamically!")
                }
            }
        }
    }
}
