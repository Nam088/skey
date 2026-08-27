import AppKit
import ApplicationServices
import Foundation

// MARK: - PermissionsService

public final class PermissionsService {
    public static let shared = PermissionsService()

    private init() {}

    /// Checks whether SKey has permission to create EventTaps and read accessibility attributes.
    /// On macOS, AXIsProcessTrusted() is the single definitive source of truth for global EventTap access.
    public func checkPermissions(prompt: Bool = false) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if prompt {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }

        return false
    }

    public func openInputMonitoringSettings() {
        _ = CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
