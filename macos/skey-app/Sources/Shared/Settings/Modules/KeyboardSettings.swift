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
        public static let smartAppSwitch      = "SKey_SmartAppSwitch"
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
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
            Keys.smartAppSwitch:      false
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        for key in [
            Keys.isVietnamese, Keys.inputMethod, Keys.charset, Keys.spellCheck, Keys.freeMarking,
            Keys.modernStyle, Keys.quickTelex, Keys.quickStartConsonant, Keys.quickEndConsonant,
            Keys.upperCaseFirstChar, Keys.swallowedKeyRestore, Keys.allowConsonantZFWJ, Keys.smartAppSwitch
        ] {
            storage.removeObject(forKey: key)
        }
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

    public var smartAppSwitchEnabled: Bool {
        get { storage.bool(forKey: Keys.smartAppSwitch, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.smartAppSwitch)
        }
    }
}
