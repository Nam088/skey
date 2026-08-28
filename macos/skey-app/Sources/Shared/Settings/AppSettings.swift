import Combine
import Foundation

// MARK: - AppSettings

/// Centralized, high-performance settings hub for the SKey Super App ecosystem.
/// - In-Memory RAM Cached: Zero-latency 0ns access on typing pipeline hot paths.
/// - Reactive: Combine-ready ObservableObject modules.
/// - Persistent: Asynchronously debounced to UserDefaults (saved permanently on disk).
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    public let storage: SettingsStorage

    // MARK: - Modules

    public let keyboard: KeyboardSettings
    public let clipboard: ClipboardSettings
    public let macro: MacroSettings
    public let general: GeneralSettings
    public let shortcuts: ShortcutSettings
    public let translator: TranslatorSettings

    private var allModules: [any SettingsModule] {
        [keyboard, clipboard, macro, general, shortcuts, translator]
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        self.keyboard = KeyboardSettings(storage: storage)
        self.clipboard = ClipboardSettings(storage: storage)
        self.macro = MacroSettings(storage: storage)
        self.general = GeneralSettings(storage: storage)
        self.shortcuts = ShortcutSettings(storage: storage)
        self.translator = TranslatorSettings(storage: storage)
    }

    /// Resets all modules across the entire application to factory defaults
    public func resetAll() {
        for module in allModules {
            module.resetToDefaults()
        }
    }
}
