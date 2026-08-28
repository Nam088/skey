import Combine
import Foundation

// MARK: - TranslatorSettings

public final class TranslatorSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Translator_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let enginesData     = "SKey_Translator_EnginesData"
        public static let targetLanguage  = "SKey_Translator_TargetLanguage"
        public static let autoDetectSource = "SKey_Translator_AutoDetect"
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.targetLanguage:   "vi",
            Keys.autoDetectSource: true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        storage.removeObject(forKey: Keys.enginesData)
        storage.removeObject(forKey: Keys.targetLanguage)
        storage.removeObject(forKey: Keys.autoDetectSource)
    }

    public var engines: [TranslationEngineConfig] {
        get {
            if let data = storage.data(forKey: Keys.enginesData),
               let decoded = try? JSONDecoder().decode([TranslationEngineConfig].self, from: data),
               !decoded.isEmpty {
                return decoded
            }
            return TranslationEngineConfig.defaultList
        }
        set {
            objectWillChange.send()
            if let encoded = try? JSONEncoder().encode(newValue) {
                storage.set(encoded, forKey: Keys.enginesData)
            }
        }
    }

    public var targetLanguage: String {
        get { storage.string(forKey: Keys.targetLanguage, default: "vi") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.targetLanguage)
        }
    }

    public var autoDetectSource: Bool {
        get { storage.bool(forKey: Keys.autoDetectSource, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.autoDetectSource)
        }
    }

    // MARK: - Reordering

    public func moveEngine(from source: IndexSet, to destination: Int) {
        objectWillChange.send()
        var current = engines
        current.move(fromOffsets: source, toOffset: destination)
        engines = current
    }

    public func moveEngineUp(at index: Int) {
        guard index > 0 else { return }
        objectWillChange.send()
        var current = engines
        current.swapAt(index, index - 1)
        engines = current
    }

    public func moveEngineDown(at index: Int) {
        guard index < engines.count - 1 else { return }
        objectWillChange.send()
        var current = engines
        current.swapAt(index, index + 1)
        engines = current
    }

    public func updateApiKey(for type: TranslationEngineType, key: String) {
        objectWillChange.send()
        var current = engines
        if let idx = current.firstIndex(where: { $0.type == type }) {
            current[idx].apiKey = key
            engines = current
        }
    }

    public func toggleEngine(for type: TranslationEngineType, isEnabled: Bool) {
        objectWillChange.send()
        var current = engines
        if let idx = current.firstIndex(where: { $0.type == type }) {
            current[idx].isEnabled = isEnabled
            engines = current
        }
    }
}
