import Foundation
import ServiceManagement

// MARK: - LaunchAtLoginService

/// Manages registration of SKey with macOS 13+ (Ventura, Sonoma, Sequoia) ServiceManagement.
public enum LaunchAtLoginService {

    /// Current registration status directly from macOS system service
    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    /// Register or unregister SKey as a Login Item in macOS System Settings -> General -> Login Items
    @discardableResult
    public static func setEnabled(_ enable: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        skeyLog("[LaunchAtLogin] Registered SMAppService.mainApp successfully", category: .general)
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        skeyLog("[LaunchAtLogin] Unregistered SMAppService.mainApp successfully", category: .general)
                    }
                }
                return true
            } catch {
                skeyLog("[LaunchAtLogin] Error setting enabled \(enable): \(error.localizedDescription)", category: .general)
                return false
            }
        }
        return false
    }

    /// Syncs stored preference with system registration state on launch
    public static func syncOnLaunch() {
        let desired = AppSettings.shared.general.launchAtLogin
        if desired != isEnabled {
            _ = setEnabled(desired)
        }
    }
}
