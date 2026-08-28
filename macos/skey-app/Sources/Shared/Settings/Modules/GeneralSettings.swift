import Combine
import Foundation
import ServiceManagement

// MARK: - GeneralSettings

public final class GeneralSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_General_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let launchAtLogin = "SKey_LaunchAtLogin"
        public static let appLanguage   = "SKey_AppLanguage"
        public static let checkUpdates  = "SKey_CheckUpdates"
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.launchAtLogin: false,
            Keys.appLanguage:   "vi",
            Keys.checkUpdates:  true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        storage.removeObject(forKey: Keys.launchAtLogin)
        storage.removeObject(forKey: Keys.appLanguage)
        storage.removeObject(forKey: Keys.checkUpdates)
        LaunchAtLoginService.setEnabled(false)
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

    public var checkUpdates: Bool {
        get { storage.bool(forKey: Keys.checkUpdates, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.checkUpdates)
        }
    }
}
