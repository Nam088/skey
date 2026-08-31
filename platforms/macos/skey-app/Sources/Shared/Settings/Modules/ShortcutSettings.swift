import Combine
import Foundation

// MARK: - Preset Definition

public struct ShortcutPresetItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let shortcut: KeyShortcut

    public init(id: String, name: String, shortcut: KeyShortcut) {
        self.id = id
        self.name = name
        self.shortcut = shortcut
    }
}

// MARK: - ShortcutSettings

public final class ShortcutSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Shortcut_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let languageTogglePreset   = "SKey_Shortcut_LanguageTogglePreset"
        public static let languageToggleCustom   = "SKey_Shortcut_LanguageToggleCustom"

        public static let clipboardPreset        = "SKey_Shortcut_ClipboardPreset"
        public static let clipboardCustom        = "SKey_Shortcut_ClipboardCustom"

        public static let cleanerPreset          = "SKey_Shortcut_CleanerPreset"
        public static let cleanerCustom          = "SKey_Shortcut_CleanerCustom"
        public static let cleanerEnabled         = "SKey_Shortcut_CleanerEnabled"

        public static let aiPreset               = "SKey_Shortcut_AIPreset"
        public static let aiCustom               = "SKey_Shortcut_AICustom"
    }

    // MARK: - Preset Collections

    public static let languagePresets: [ShortcutPresetItem] = [
        ShortcutPresetItem(id: "optZ", name: "Option + Z (⌥Z)", shortcut: .optionZ),
        ShortcutPresetItem(id: "ctrlShift", name: "Control + Shift (⌃⇧)", shortcut: .ctrlShift),
        ShortcutPresetItem(id: "ctrlOptionZ", name: "Control + Option + Z (⌃⌥Z)", shortcut: .ctrlOptionZ),
        ShortcutPresetItem(id: "cmdShift", name: "Command + Shift (⌘⇧)", shortcut: .cmdShift),
        ShortcutPresetItem(id: "optionShift", name: "Option + Shift (⌥⇧)", shortcut: .optionShift),
        ShortcutPresetItem(id: "ctrlSpace", name: "Control + Space (⌃Space)", shortcut: .ctrlSpace)
    ]

    public static let clipboardPresets: [ShortcutPresetItem] = [
        ShortcutPresetItem(id: "optV", name: "Option + V (⌥V)", shortcut: .optionV),
        ShortcutPresetItem(id: "cmdShiftV", name: "Command + Shift + V (⌘⇧V)", shortcut: .cmdShiftV),
        ShortcutPresetItem(id: "ctrlOptionV", name: "Control + Option + V (⌃⌥V)", shortcut: .ctrlOptionV),
        ShortcutPresetItem(id: "optC", name: "Option + C (⌥C)", shortcut: .optionC)
    ]

    public static let cleanerPresets: [ShortcutPresetItem] = [
        ShortcutPresetItem(id: "optShiftK", name: "Option + Shift + K (⌥⇧K)", shortcut: .optionShiftK),
        ShortcutPresetItem(id: "optShiftC", name: "Option + Shift + C (⌥⇧C)", shortcut: .optionShiftC),
        ShortcutPresetItem(id: "ctrlOptionK", name: "Control + Option + K (⌃⌥K)", shortcut: .ctrlOptionK)
    ]

    public static let aiPresets: [ShortcutPresetItem] = [
        ShortcutPresetItem(id: "optSpace", name: "Option + Space (⌥Space)", shortcut: .optionSpace),
        ShortcutPresetItem(id: "ctrlOptionSpace", name: "Control + Option + Space (⌃⌥Space)", shortcut: .ctrlOptionSpace),
        ShortcutPresetItem(id: "cmdShiftSpace", name: "Command + Shift + Space (⌘⇧Space)", shortcut: .cmdShiftSpace)
    ]

    // MARK: - Init & Defaults

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.languageTogglePreset: "optZ",
            Keys.clipboardPreset:      "optV",
            Keys.cleanerPreset:        "optShiftK",
            Keys.cleanerEnabled:       true,
            Keys.aiPreset:             "optSpace"
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        for key in [
            Keys.languageTogglePreset, Keys.languageToggleCustom,
            Keys.clipboardPreset, Keys.clipboardCustom,
            Keys.cleanerPreset, Keys.cleanerCustom, Keys.cleanerEnabled,
            Keys.aiPreset, Keys.aiCustom
        ] {
            storage.removeObject(forKey: key)
        }
    }

    // MARK: - 1. Language Toggle Shortcut

    public var languageTogglePreset: String {
        get { storage.string(forKey: Keys.languageTogglePreset, default: "optZ") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.languageTogglePreset)
        }
    }

    public var languageToggleShortcut: KeyShortcut {
        get {
            if languageTogglePreset != "custom",
               let preset = Self.languagePresets.first(where: { $0.id == languageTogglePreset }) {
                return preset.shortcut
            }
            if let data = storage.data(forKey: Keys.languageToggleCustom),
               let custom = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
                return custom
            }
            return .optionZ
        }
        set {
            objectWillChange.send()
            if let matched = Self.languagePresets.first(where: { $0.shortcut == newValue }) {
                storage.set(matched.id, forKey: Keys.languageTogglePreset)
            } else {
                storage.set("custom", forKey: Keys.languageTogglePreset)
                if let data = try? JSONEncoder().encode(newValue) {
                    storage.set(data, forKey: Keys.languageToggleCustom)
                }
            }
        }
    }

    // MARK: - 2. Clipboard Shortcut

    public var clipboardPreset: String {
        get { storage.string(forKey: Keys.clipboardPreset, default: "optV") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.clipboardPreset)
        }
    }

    public var clipboardShortcut: KeyShortcut {
        get {
            if clipboardPreset != "custom",
               let preset = Self.clipboardPresets.first(where: { $0.id == clipboardPreset }) {
                return preset.shortcut
            }
            if let data = storage.data(forKey: Keys.clipboardCustom),
               let custom = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
                return custom
            }
            return .optionV
        }
        set {
            objectWillChange.send()
            if let matched = Self.clipboardPresets.first(where: { $0.shortcut == newValue }) {
                storage.set(matched.id, forKey: Keys.clipboardPreset)
            } else {
                storage.set("custom", forKey: Keys.clipboardPreset)
                if let data = try? JSONEncoder().encode(newValue) {
                    storage.set(data, forKey: Keys.clipboardCustom)
                }
            }
        }
    }

    // MARK: - 3. Keyboard Cleaner Shortcut

    public var cleanerEnabled: Bool {
        get { storage.bool(forKey: Keys.cleanerEnabled, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.cleanerEnabled)
        }
    }

    public var cleanerPreset: String {
        get { storage.string(forKey: Keys.cleanerPreset, default: "optShiftK") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.cleanerPreset)
        }
    }

    public var cleanerShortcut: KeyShortcut {
        get {
            if cleanerPreset != "custom",
               let preset = Self.cleanerPresets.first(where: { $0.id == cleanerPreset }) {
                return preset.shortcut
            }
            if let data = storage.data(forKey: Keys.cleanerCustom),
               let custom = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
                return custom
            }
            return .optionShiftK
        }
        set {
            objectWillChange.send()
            if let matched = Self.cleanerPresets.first(where: { $0.shortcut == newValue }) {
                storage.set(matched.id, forKey: Keys.cleanerPreset)
            } else {
                storage.set("custom", forKey: Keys.cleanerPreset)
                if let data = try? JSONEncoder().encode(newValue) {
                    storage.set(data, forKey: Keys.cleanerCustom)
                }
            }
        }
    }

    // MARK: - 4. AI Shortcut

    public var aiPreset: String {
        get { storage.string(forKey: Keys.aiPreset, default: "optSpace") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.aiPreset)
        }
    }

    public var aiShortcut: KeyShortcut {
        get {
            if aiPreset != "custom",
               let preset = Self.aiPresets.first(where: { $0.id == aiPreset }) {
                return preset.shortcut
            }
            if let data = storage.data(forKey: Keys.aiCustom),
               let custom = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
                return custom
            }
            return .optionSpace
        }
        set {
            objectWillChange.send()
            if let matched = Self.aiPresets.first(where: { $0.shortcut == newValue }) {
                storage.set(matched.id, forKey: Keys.aiPreset)
            } else {
                storage.set("custom", forKey: Keys.aiPreset)
                if let data = try? JSONEncoder().encode(newValue) {
                    storage.set(data, forKey: Keys.aiCustom)
                }
            }
        }
    }

    // MARK: - Shortcut Conflict Detection

    public enum ShortcutTarget: String, CaseIterable, Identifiable {
        case languageToggle = "languageToggle"
        case clipboard      = "clipboard"
        case cleaner        = "cleaner"
        case ai             = "ai"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .languageToggle: return L10n("keyboard.shortcut.toggleTitle")
            case .clipboard:      return L10n("clipboard.option.shortcut")
            case .cleaner:        return L10n("cleaner.option.shortcut")
            case .ai:             return L10n("ai.option.shortcut")
            }
        }
    }

    public func shortcut(for target: ShortcutTarget) -> KeyShortcut {
        switch target {
        case .languageToggle: return languageToggleShortcut
        case .clipboard:      return clipboardShortcut
        case .cleaner:        return cleanerShortcut
        case .ai:             return aiShortcut
        }
    }

    public func findConflict(for shortcut: KeyShortcut, excluding target: ShortcutTarget) -> ShortcutTarget? {
        for other in ShortcutTarget.allCases where other != target {
            if other == .cleaner && !cleanerEnabled {
                continue
            }
            if self.shortcut(for: other) == shortcut {
                return other
            }
        }
        return nil
    }

    // MARK: - Default Presets & Reset Helpers

    public func defaultPresetId(for target: ShortcutTarget) -> String {
        switch target {
        case .languageToggle: return "optZ"
        case .clipboard:      return "optV"
        case .cleaner:        return "optShiftK"
        case .ai:             return "optSpace"
        }
    }

    public func defaultShortcut(for target: ShortcutTarget) -> KeyShortcut {
        switch target {
        case .languageToggle: return .optionZ
        case .clipboard:      return .optionV
        case .cleaner:        return .optionShiftK
        case .ai:             return .optionSpace
        }
    }

    public func isDefault(for target: ShortcutTarget) -> Bool {
        return shortcut(for: target) == defaultShortcut(for: target)
    }

    public func resetToDefault(for target: ShortcutTarget) {
        objectWillChange.send()
        switch target {
        case .languageToggle:
            languageTogglePreset = "optZ"
            storage.removeObject(forKey: Keys.languageToggleCustom)
        case .clipboard:
            clipboardPreset = "optV"
            storage.removeObject(forKey: Keys.clipboardCustom)
        case .cleaner:
            cleanerPreset = "optShiftK"
            storage.removeObject(forKey: Keys.cleanerCustom)
        case .ai:
            aiPreset = "optSpace"
            storage.removeObject(forKey: Keys.aiCustom)
        }
    }
}
