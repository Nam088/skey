import Combine
import Foundation

// MARK: - MacroSettings

public final class MacroSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Macro_"
    private let storage: SettingsStorage
    private let defaults: UserDefaults

    public enum Keys {
        public static let isEnabled              = "SKey_MacroEnabled"
        public static let autoCaps               = "SKey_MacroAutoCaps"
        public static let inEnglishMode          = "SKey_MacroInEnglishMode"
        public static let dynamicVariables       = "SKey_MacroDynamicVariables"
        public static let directConstantsEnabled = "SKey_MacroDirectConstantsEnabled"
        public static let constantPrefix         = "SKey_MacroConstantPrefix"
        public static let itemsData              = "SKey_MacroItemsData"
        public static let constantsData          = "SKey_MacroConstantsData"
    }

    public static let defaultItems: [MacroItem] = [
        MacroItem(shortcut: "vn", replacement: "Việt Nam"),
        MacroItem(shortcut: "hn", replacement: "Hà Nội"),
        MacroItem(shortcut: "sg", replacement: "Sài Gòn"),
        MacroItem(shortcut: "đc", replacement: "được"),
        MacroItem(shortcut: "dc", replacement: "được"),
        MacroItem(shortcut: "ko", replacement: "không"),
        MacroItem(shortcut: "ng", replacement: "người"),
        MacroItem(shortcut: "tt", replacement: "thông tin"),
        MacroItem(shortcut: "skey", replacement: "SKey - Bộ gõ tiếng Việt macOS")
    ]

    public static let defaultConstants: [MacroConstant] = [
        MacroConstant(key: "email", value: "nam077.work@gmail.com"),
        MacroConstant(key: "sdt", value: "0901234567"),
        MacroConstant(key: "ten", value: "Nguyễn Văn Nam")
    ]

    @Published public var items: [MacroItem] = []
    @Published public var constants: [MacroConstant] = []

    public init(storage: SettingsStorage = .shared, defaults: UserDefaults = .standard) {
        self.storage = storage
        self.defaults = defaults
        super.init()
        registerDefaults(in: storage)
        loadItems()
        loadConstants()
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.isEnabled:              false,
            Keys.autoCaps:               true,
            Keys.inEnglishMode:          true,
            Keys.dynamicVariables:       true,
            Keys.directConstantsEnabled: true,
            Keys.constantPrefix:         ":"
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        storage.removeObject(forKey: Keys.isEnabled)
        storage.removeObject(forKey: Keys.autoCaps)
        storage.removeObject(forKey: Keys.inEnglishMode)
        storage.removeObject(forKey: Keys.dynamicVariables)
        storage.removeObject(forKey: Keys.directConstantsEnabled)
        storage.removeObject(forKey: Keys.constantPrefix)
        self.items = Self.defaultItems
        self.constants = Self.defaultConstants
        saveItems()
        saveConstants()
    }

    public var isEnabled: Bool {
        get { storage.bool(forKey: Keys.isEnabled, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.isEnabled)
        }
    }

    public var autoCaps: Bool {
        get { storage.bool(forKey: Keys.autoCaps, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.autoCaps)
        }
    }

    public var inEnglishMode: Bool {
        get { storage.bool(forKey: Keys.inEnglishMode, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.inEnglishMode)
        }
    }

    public var dynamicVariablesEnabled: Bool {
        get { storage.bool(forKey: Keys.dynamicVariables, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.dynamicVariables)
        }
    }

    public var directConstantsEnabled: Bool {
        get { storage.bool(forKey: Keys.directConstantsEnabled, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.directConstantsEnabled)
            MacroEngine.shared.reloadMacros()
        }
    }

    public var constantPrefix: String {
        get { storage.string(forKey: Keys.constantPrefix, default: ":") }
        set {
            objectWillChange.send()
            let sanitized = newValue.trimmingCharacters(in: .whitespaces)
            storage.set(sanitized.isEmpty ? ":" : sanitized, forKey: Keys.constantPrefix)
            MacroEngine.shared.reloadMacros()
        }
    }

    // MARK: - Items Storage

    private func loadItems() {
        if let data = defaults.data(forKey: Keys.itemsData),
           let decoded = try? JSONDecoder().decode([MacroItem].self, from: data) {
            self.items = decoded
        } else {
            self.items = Self.defaultItems
            saveItems()
        }
    }

    public func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: Keys.itemsData)
        }
        MacroEngine.shared.reloadMacros()
    }

    public func add(shortcut: String, replacement: String) {
        let s = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !r.isEmpty else { return }

        objectWillChange.send()
        if let index = items.firstIndex(where: { $0.shortcut.lowercased() == s.lowercased() }) {
            items[index].replacement = r
        } else {
            items.insert(MacroItem(shortcut: s, replacement: r), at: 0)
        }
        saveItems()
    }

    public func remove(item: MacroItem) {
        objectWillChange.send()
        items.removeAll(where: { $0.id == item.id })
        saveItems()
    }

    public func remove(at offsets: IndexSet) {
        objectWillChange.send()
        items.remove(atOffsets: offsets)
        saveItems()
    }

    // MARK: - Constants Storage

    private func loadConstants() {
        if let data = defaults.data(forKey: Keys.constantsData),
           let decoded = try? JSONDecoder().decode([MacroConstant].self, from: data) {
            self.constants = decoded
        } else {
            self.constants = Self.defaultConstants
            saveConstants()
        }
    }

    public func saveConstants() {
        if let encoded = try? JSONEncoder().encode(constants) {
            defaults.set(encoded, forKey: Keys.constantsData)
        }
        MacroEngine.shared.reloadMacros()
    }

    public func addConstant(key: String, value: String) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "$", with: "")
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty, !v.isEmpty else { return }

        objectWillChange.send()
        if let index = constants.firstIndex(where: { $0.key.lowercased() == k.lowercased() }) {
            constants[index].value = v
        } else {
            constants.append(MacroConstant(key: k, value: v))
        }
        saveConstants()
    }

    public func removeConstant(item: MacroConstant) {
        objectWillChange.send()
        constants.removeAll(where: { $0.id == item.id })
        saveConstants()
    }

    public func removeConstants(at offsets: IndexSet) {
        objectWillChange.send()
        constants.remove(atOffsets: offsets)
        saveConstants()
    }
}
