import Combine
import Foundation

// MARK: - MacroSettings

public final class MacroSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Macro_"
    private let storage: SettingsStorage
    private let defaults: UserDefaults

    public enum Keys {
        public static let isEnabled        = "SKey_MacroEnabled"
        public static let autoCaps         = "SKey_MacroAutoCaps"
        public static let inEnglishMode    = "SKey_MacroInEnglishMode"
        public static let itemsData        = "SKey_MacroItemsData"
    }

    public static let defaultItems: [MacroItem] = [
        MacroItem(shortcut: "vn", replacement: "Việt Nam"),
        MacroItem(shortcut: "hn", replacement: "Hà Nội"),
        MacroItem(shortcut: "sg", replacement: "Sài Gòn"),
        MacroItem(shortcut: "dc", replacement: "được"),
        MacroItem(shortcut: "ko", replacement: "không"),
        MacroItem(shortcut: "ng", replacement: "người"),
        MacroItem(shortcut: "tt", replacement: "thông tin"),
        MacroItem(shortcut: "skey", replacement: "SKey - Bộ gõ tiếng Việt macOS")
    ]

    @Published public var items: [MacroItem] = []

    public init(storage: SettingsStorage = .shared, defaults: UserDefaults = .standard) {
        self.storage = storage
        self.defaults = defaults
        super.init()
        registerDefaults(in: storage)
        loadItems()
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.isEnabled:     false,
            Keys.autoCaps:      true,
            Keys.inEnglishMode: true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        storage.removeObject(forKey: Keys.isEnabled)
        storage.removeObject(forKey: Keys.autoCaps)
        storage.removeObject(forKey: Keys.inEnglishMode)
        self.items = Self.defaultItems
        saveItems()
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
}
