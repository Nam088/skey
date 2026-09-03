import Combine
import Foundation

// MARK: - KeyboardSettings

public final class KeyboardSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Keyboard_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let isVietnamese        = "SKey_IsVietnamese"
        public static let inputMethod         = "SKey_InputMethod"
        public static let charset             = "SKey_Charset"
        public static let spellCheck          = "SKey_SpellCheck"
        public static let freeMarking         = "SKey_FreeMarking"
        public static let modernStyle         = "SKey_ModernStyle"
        public static let quickTelex          = "SKey_QuickTelex"
        public static let quickStartConsonant = "SKey_QuickStartConsonant"
        public static let quickEndConsonant   = "SKey_QuickEndConsonant"
        public static let upperCaseFirstChar  = "SKey_UpperCaseFirstChar"
        public static let swallowedKeyRestore = "SKey_SwallowedKeyRestore"
        public static let allowConsonantZFWJ  = "SKey_AllowConsonantZFWJ"
        public static let smartCoderMode      = "SKey_SmartCoderMode"
        public static let smartAppSwitch      = "SKey_SmartAppSwitch"
        public static let appExclusionEnabled = "SKey_AppExclusionEnabled"
        public static let excludedApps        = "SKey_ExcludedApps"
    }

    private var cachedExcludedBundleIDs: Set<String> = []
    private var cacheLock = os_unfair_lock()

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
        rebuildExcludedAppsCache()
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.isVietnamese:        true,
            Keys.inputMethod:         0,
            Keys.charset:             "Unicode",
            Keys.spellCheck:          true,
            Keys.freeMarking:         true,
            Keys.modernStyle:         false,
            Keys.quickTelex:          false,
            Keys.quickStartConsonant: false,
            Keys.quickEndConsonant:   false,
            Keys.upperCaseFirstChar:  false,
            Keys.swallowedKeyRestore: true,
            Keys.allowConsonantZFWJ:  false,
            Keys.smartCoderMode:      false,
            Keys.smartAppSwitch:      false,
            Keys.appExclusionEnabled: true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        for key in [
            Keys.isVietnamese, Keys.inputMethod, Keys.charset, Keys.spellCheck, Keys.freeMarking,
            Keys.modernStyle, Keys.quickTelex, Keys.quickStartConsonant, Keys.quickEndConsonant,
            Keys.upperCaseFirstChar, Keys.swallowedKeyRestore, Keys.allowConsonantZFWJ, Keys.smartAppSwitch,
            Keys.appExclusionEnabled, Keys.excludedApps
        ] {
            storage.removeObject(forKey: key)
        }
        rebuildExcludedAppsCache()
    }

    public var isVietnamese: Bool {
        get { storage.bool(forKey: Keys.isVietnamese, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.isVietnamese)
        }
    }

    public var inputMethodRawValue: Int32 {
        get { Int32(storage.integer(forKey: Keys.inputMethod, default: 0)) }
        set {
            objectWillChange.send()
            storage.set(Int(newValue), forKey: Keys.inputMethod)
        }
    }

    public var inputMethod: InputMethodType {
        get { InputMethodType(rawValue: inputMethodRawValue) ?? .telex }
        set { inputMethodRawValue = newValue.rawValue }
    }

    public var charset: String {
        get { storage.string(forKey: Keys.charset, default: "Unicode") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.charset)
        }
    }

    public var spellCheck: Bool {
        get { storage.bool(forKey: Keys.spellCheck, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.spellCheck)
        }
    }

    public var freeMarking: Bool {
        get { storage.bool(forKey: Keys.freeMarking, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.freeMarking)
        }
    }

    public var modernStyle: Bool {
        get { storage.bool(forKey: Keys.modernStyle, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.modernStyle)
        }
    }

    public var quickTelex: Bool {
        get { storage.bool(forKey: Keys.quickTelex, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.quickTelex)
        }
    }

    public var quickStartConsonant: Bool {
        get { storage.bool(forKey: Keys.quickStartConsonant, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.quickStartConsonant)
        }
    }

    public var quickEndConsonant: Bool {
        get { storage.bool(forKey: Keys.quickEndConsonant, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.quickEndConsonant)
        }
    }

    public var upperCaseFirstChar: Bool {
        get { storage.bool(forKey: Keys.upperCaseFirstChar, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.upperCaseFirstChar)
        }
    }

    public var swallowedKeyRestore: Bool {
        get { storage.bool(forKey: Keys.swallowedKeyRestore, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.swallowedKeyRestore)
        }
    }

    public var allowConsonantZFWJ: Bool {
        get { storage.bool(forKey: Keys.allowConsonantZFWJ, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.allowConsonantZFWJ)
        }
    }

    public var smartCoderMode: Bool {
        get { storage.bool(forKey: Keys.smartCoderMode, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.smartCoderMode)
        }
    }

    public var smartAppSwitchEnabled: Bool {
        get { storage.bool(forKey: Keys.smartAppSwitch, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.smartAppSwitch)
        }
    }

    // MARK: - Excluded Apps Management

    public var isExclusionEnabled: Bool {
        get { storage.bool(forKey: Keys.appExclusionEnabled, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.appExclusionEnabled)
            rebuildExcludedAppsCache()
        }
    }

    public var excludedApps: [ExcludedApp] {
        get {
            guard let data = storage.data(forKey: Keys.excludedApps),
                  let list = try? JSONDecoder().decode([ExcludedApp].self, from: data) else {
                return []
            }
            return list
        }
        set {
            objectWillChange.send()
            if let data = try? JSONEncoder().encode(newValue) {
                storage.set(data, forKey: Keys.excludedApps)
            } else {
                storage.removeObject(forKey: Keys.excludedApps)
            }
            rebuildExcludedAppsCache()
        }
    }

    public func rebuildExcludedAppsCache() {
        os_unfair_lock_lock(&cacheLock)
        defer { os_unfair_lock_unlock(&cacheLock) }

        if !isExclusionEnabled {
            cachedExcludedBundleIDs.removeAll()
            return
        }

        let enabledIDs = excludedApps.filter { $0.isEnabled }.map { $0.bundleID.lowercased() }
        cachedExcludedBundleIDs = Set(enabledIDs)
    }

    /// Zero-latency O(1) in-memory check for TypingPipeline hot path
    public func isAppExcluded(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        os_unfair_lock_lock(&cacheLock)
        defer { os_unfair_lock_unlock(&cacheLock) }
        return cachedExcludedBundleIDs.contains(bundleID.lowercased())
    }

    public func addExcludedApp(bundleID: String, name: String) {
        let trimmedID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }
        var current = excludedApps
        if let idx = current.firstIndex(where: { $0.bundleID.caseInsensitiveCompare(trimmedID) == .orderedSame }) {
            current[idx].name = name.isEmpty ? current[idx].name : name
            current[idx].isEnabled = true
        } else {
            let appName = name.isEmpty ? trimmedID : name
            current.append(ExcludedApp(bundleID: trimmedID, name: appName, isEnabled: true))
        }
        excludedApps = current
    }

    public func removeExcludedApp(bundleID: String) {
        var current = excludedApps
        current.removeAll(where: { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame })
        excludedApps = current
    }

    public func toggleExcludedApp(bundleID: String) {
        var current = excludedApps
        if let idx = current.firstIndex(where: { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            current[idx].isEnabled.toggle()
            excludedApps = current
        }
    }

    public func clearExcludedApps() {
        excludedApps = []
    }
}

