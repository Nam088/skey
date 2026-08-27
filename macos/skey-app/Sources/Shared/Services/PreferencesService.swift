import Foundation

// MARK: - PreferencesService

public final class PreferencesService {
    public static let shared = PreferencesService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        // Keyboard Feature Keys
        static let inputMethod          = "SKey_InputMethod"
        static let spellCheck           = "SKey_SpellCheck"
        static let freeMarking          = "SKey_FreeMarking"
        static let modernStyle          = "SKey_ModernStyle"
        static let isVietnamese         = "SKey_IsVietnamese"
        static let quickTelex           = "SKey_QuickTelex"
        static let quickStartConsonant  = "SKey_QuickStartConsonant"
        static let quickEndConsonant    = "SKey_QuickEndConsonant"
        static let upperCaseFirstChar   = "SKey_UpperCaseFirstChar"
        static let swallowedKeyRestore  = "SKey_SwallowedKeyRestore"
        static let allowConsonantZFWJ   = "SKey_AllowConsonantZFWJ"
        static let smartAppSwitch       = "SKey_SmartAppSwitch"

        // Clipboard Feature Keys
        static let clipboardEnabled     = "SKey_ClipboardEnabled"
        static let clipboardLimit       = "SKey_ClipboardLimit"
    }

    private init() {
        defaults.register(defaults: [
            Keys.isVietnamese:        true,
            Keys.inputMethod:         0,
            Keys.spellCheck:          true,
            Keys.freeMarking:         true,
            Keys.modernStyle:         false,
            Keys.quickTelex:          false,
            Keys.quickStartConsonant: false,
            Keys.quickEndConsonant:   false,
            Keys.upperCaseFirstChar:  false,
            Keys.swallowedKeyRestore: true,
            Keys.allowConsonantZFWJ:  false,
            Keys.smartAppSwitch:      true,
            Keys.clipboardEnabled:    true,
            Keys.clipboardLimit:      50
        ])
    }

    // MARK: - Keyboard Preferences

    public var isVietnamese: Bool {
        get { defaults.bool(forKey: Keys.isVietnamese) }
        set { defaults.set(newValue, forKey: Keys.isVietnamese) }
    }

    public var inputMethodRawValue: Int32 {
        get { Int32(defaults.integer(forKey: Keys.inputMethod)) }
        set { defaults.set(newValue, forKey: Keys.inputMethod) }
    }

    public var spellCheck: Bool {
        get { defaults.bool(forKey: Keys.spellCheck) }
        set { defaults.set(newValue, forKey: Keys.spellCheck) }
    }

    public var freeMarking: Bool {
        get { defaults.bool(forKey: Keys.freeMarking) }
        set { defaults.set(newValue, forKey: Keys.freeMarking) }
    }

    public var modernStyle: Bool {
        get { defaults.bool(forKey: Keys.modernStyle) }
        set { defaults.set(newValue, forKey: Keys.modernStyle) }
    }

    public var quickTelex: Bool {
        get { defaults.bool(forKey: Keys.quickTelex) }
        set { defaults.set(newValue, forKey: Keys.quickTelex) }
    }

    public var quickStartConsonant: Bool {
        get { defaults.bool(forKey: Keys.quickStartConsonant) }
        set { defaults.set(newValue, forKey: Keys.quickStartConsonant) }
    }

    public var quickEndConsonant: Bool {
        get { defaults.bool(forKey: Keys.quickEndConsonant) }
        set { defaults.set(newValue, forKey: Keys.quickEndConsonant) }
    }

    public var upperCaseFirstChar: Bool {
        get { defaults.bool(forKey: Keys.upperCaseFirstChar) }
        set { defaults.set(newValue, forKey: Keys.upperCaseFirstChar) }
    }

    public var swallowedKeyRestore: Bool {
        get { defaults.bool(forKey: Keys.swallowedKeyRestore) }
        set { defaults.set(newValue, forKey: Keys.swallowedKeyRestore) }
    }

    public var allowConsonantZFWJ: Bool {
        get { defaults.bool(forKey: Keys.allowConsonantZFWJ) }
        set { defaults.set(newValue, forKey: Keys.allowConsonantZFWJ) }
    }

    public var smartAppSwitchEnabled: Bool {
        get { defaults.bool(forKey: Keys.smartAppSwitch) }
        set { defaults.set(newValue, forKey: Keys.smartAppSwitch) }
    }

    // MARK: - Clipboard Preferences

    public var isClipboardEnabled: Bool {
        get { defaults.bool(forKey: Keys.clipboardEnabled) }
        set { defaults.set(newValue, forKey: Keys.clipboardEnabled) }
    }

    public var clipboardLimit: Int {
        get { defaults.integer(forKey: Keys.clipboardLimit) }
        set { defaults.set(newValue, forKey: Keys.clipboardLimit) }
    }
}
