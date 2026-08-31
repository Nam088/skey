import AppKit
import ApplicationServices
import Combine
import Foundation

// MARK: - PermissionsService

public final class PermissionsService: ObservableObject {
    public static let shared = PermissionsService()
    
    @Published public private(set) var hasInputMonitoringPermission = false
    @Published public private(set) var hasAccessibilityPermission = false
    
    private var cachedStatus: Bool?
    private var lastCheckTime: Date?
    private let cacheValidityInterval: TimeInterval = 5.0 // Cache valid for 5 seconds
    
    private init() {}
    
    /// Checks whether SKey has BOTH Accessibility AND Input Monitoring permissions.
    /// Uses caching to avoid expensive system calls on hot paths.
    public func checkPermissions(prompt: Bool = false) -> Bool {
        // Return cached result if still valid (avoid repeated system calls)
        if let cached = cachedStatus,
           let lastCheck = lastCheckTime,
           Date().timeIntervalSince(lastCheck) < cacheValidityInterval {
            return cached
        }
        
        // Check Accessibility permission (required for EventTap + AX attributes)
        let hasAccessibility = AXIsProcessTrusted()
        
        // Check Input Monitoring permission (required for CGEventTap keyboard capture)
        // Note: There's no direct API to check Input Monitoring, so we infer from EventTap creation
        let hasInputMonitoring = testInputMonitoringPermission()
        
        let hasAllPermissions = hasAccessibility && hasInputMonitoring
        
        // Update cache
        cachedStatus = hasAllPermissions
        lastCheckTime = Date()
        
        // Update published properties for reactive UI
        DispatchQueue.main.async { [weak self] in
            self?.hasAccessibilityPermission = hasAccessibility
            self?.hasInputMonitoringPermission = hasInputMonitoring
        }
        
        if !hasAllPermissions && prompt {
            // Prompt for both permissions
            if !hasAccessibility {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(opts)
            }
            if !hasInputMonitoring {
                openInputMonitoringSettings()
            }
            
            // Invalidate cache after prompting (user might grant permission)
            invalidateCache()
        }
        
        return hasAllPermissions
    }
    
    /// Test if Input Monitoring permission is granted by attempting to create a temporary EventTap.
    /// Returns true if EventTap can be created successfully.
    private func testInputMonitoringPermission() -> Bool {
        // Try to create a minimal EventTap - if it fails, Input Monitoring is not granted
        let eventMask: UInt64 = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, _, _ in nil }, // No-op callback
            userInfo: nil
        ) else {
            return false
        }
        
        // Successfully created - clean up immediately
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }
    
    /// Force refresh permission status (call after user returns from System Settings)
    public func refreshPermissions() {
        invalidateCache()
        _ = checkPermissions(prompt: false)
    }
    
    /// Clear cached permission status
    private func invalidateCache() {
        cachedStatus = nil
        lastCheckTime = nil
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
