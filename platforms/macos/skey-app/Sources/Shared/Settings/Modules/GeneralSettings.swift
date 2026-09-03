import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

// MARK: - AppTheme

public enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return L10n("general.theme.system")
        case .light:  return L10n("general.theme.light")
        case .dark:   return L10n("general.theme.dark")
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - GeneralSettings

public final class GeneralSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_General_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let launchAtLogin     = "SKey_LaunchAtLogin"
        public static let appLanguage       = "SKey_AppLanguage"
        public static let appTheme          = "SKey_AppTheme"
        public static let checkUpdates      = "SKey_CheckUpdates"
        public static let debugMode         = "SKey_DebugMode"
        public static let inlineCalculator  = "SKey_InlineCalculator"
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
        Self.applyTheme(self.appTheme)
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.launchAtLogin:     false,
            Keys.appLanguage:       "vi",
            Keys.appTheme:          AppTheme.system.rawValue,
            Keys.checkUpdates:      true,
            Keys.debugMode:         false,
            Keys.inlineCalculator:  true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        storage.removeObject(forKey: Keys.launchAtLogin)
        storage.removeObject(forKey: Keys.appLanguage)
        storage.removeObject(forKey: Keys.appTheme)
        storage.removeObject(forKey: Keys.checkUpdates)
        storage.removeObject(forKey: Keys.debugMode)
        storage.removeObject(forKey: Keys.inlineCalculator)
        LaunchAtLoginService.setEnabled(false)
        Self.applyTheme(.system)
    }

    public var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                let status = SMAppService.mainApp.status
                if status == .enabled { return true }
            }
            return storage.bool(forKey: Keys.launchAtLogin, default: false)
        }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.launchAtLogin)
            LaunchAtLoginService.setEnabled(newValue)
        }
    }

    public var appLanguage: String {
        get { storage.string(forKey: Keys.appLanguage, default: "vi") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.appLanguage)
        }
    }

    public var appTheme: AppTheme {
        get {
            let raw = storage.string(forKey: Keys.appTheme, default: AppTheme.system.rawValue)
            return AppTheme(rawValue: raw) ?? .system
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Keys.appTheme)
            Self.applyTheme(newValue)
        }
    }

    public static func applyTheme(_ theme: AppTheme) {
        DispatchQueue.main.async {
            // Guard against headless test runners where NSApp is not yet configured
            if let app = NSApp {
                app.appearance = theme.nsAppearance
            }
        }
    }

    public var checkUpdates: Bool {
        get { storage.bool(forKey: Keys.checkUpdates, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.checkUpdates)
        }
    }

    /// Development Debug Mode: Strictly enforced to DEV/DEBUG builds only.
    /// In Release mode, always returns false and cannot be enabled.
    public var isDebugMode: Bool {
        get {
            #if DEBUG
            return storage.bool(forKey: Keys.debugMode, default: false)
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.debugMode)
            #endif
        }
    }

    public var inlineCalculatorEnabled: Bool {
        get { storage.bool(forKey: Keys.inlineCalculator, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.inlineCalculator)
        }
    }
}

