import Cocoa
import SwiftUI

// MARK: - LocalizationService

public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()

    private let storage: SettingsStorage
    public static let storageKey = "SKey_AppLanguage"

    @Published public private(set) var activeBundle: Bundle = Bundle.main

    private init(storage: SettingsStorage = .shared) {
        self.storage = storage
        updateActiveBundle()
    }

    public var currentLanguage: AppLanguage {
        get {
            let raw = storage.string(forKey: Self.storageKey, default: "vi")
            return AppLanguage(rawValue: raw) ?? .vietnamese
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Self.storageKey)
            updateActiveBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
            NotificationCenter.default.post(name: .skeyLanguageDidChange, object: nil)
        }
    }

    public var isVietnameseActive: Bool {
        switch currentLanguage {
        case .vietnamese: return true
        case .english:    return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "vi"
            return preferred.starts(with: "vi")
        }
    }

    private func updateActiveBundle() {
        let code: String
        switch currentLanguage {
        case .vietnamese:
            code = "vi"
        case .english:
            code = "en"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "vi"
            code = preferred.starts(with: "vi") ? "vi" : "en"
        }

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.activeBundle = bundle
        } else {
            self.activeBundle = Bundle.main
        }
    }

    public func string(for key: String) -> String {
        let localized = activeBundle.localizedString(forKey: key, value: nil, table: nil)
        if localized != key {
            return localized
        }
        // Fallback to Vietnamese bundle if missing in current
        if let viPath = Bundle.main.path(forResource: "vi", ofType: "lproj"),
           let viBundle = Bundle(path: viPath) {
            let viString = viBundle.localizedString(forKey: key, value: nil, table: nil)
            if viString != key {
                return viString
            }
        }
        return key
    }

    public func string(for key: StringKey) -> String {
        return string(for: key.rawValue)
    }

    public enum StringKey: String {
        case appTitle                     = "app.title"
        case toggleLanguage               = "keyboard.menu.toggle"
        case inputMethodMenu              = "keyboard.menu.input_method"
        case spellCheck                   = "keyboard.options.spell_check"
        case freeMarking                  = "keyboard.options.free_marking"
        case modernStyle                  = "keyboard.options.modern_style"
        case smartAppSwitch               = "keyboard.options.smart_switch"
        case advancedOptions              = "keyboard.options.advanced"
        case quickTelex                   = "keyboard.advanced.quick_telex"
        case quickStartConsonant          = "keyboard.advanced.quick_start_consonant"
        case quickEndConsonant            = "keyboard.advanced.quick_end_consonant"
        case upperCaseFirstChar           = "keyboard.advanced.upper_case_first"
        case swallowedKeyRestore          = "keyboard.advanced.swallowed_restore"
        case clipboardMenu                = "clipboard.menu.title"
        case clipboardEmpty               = "clipboard.empty"
        case clearClipboard               = "clipboard.clear"
        case clearAllClipboard            = "clipboard.clearAll"
        case clipboardSearchPlaceholder   = "clipboard.search.placeholder"
        case clipboardNoMatches           = "clipboard.noMatches"
        case clipboardPaste               = "clipboard.paste"
        case clipboardPasteAsPlainText    = "clipboard.pasteAsPlainText"
        case clipboardPin                 = "clipboard.pin"
        case clipboardUnpin               = "clipboard.unpin"
        case clipboardDelete              = "clipboard.delete"
        case clipboardClearConfirmMessage = "clipboard.clear.confirmMessage"
        case clipboardClearAllConfirmMessage = "clipboard.clearAll.confirmMessage"
        case clipboardClearDontAskAgain   = "clipboard.clear.dontAskAgain"
        case clipboardCancel              = "clipboard.cancel"
        case clipboardClearConfirm        = "clipboard.clear.confirm"
        case clipboardClearAllConfirm     = "clipboard.clearAll.confirm"
        case clipboardSettings            = "clipboard.settings"
        case clipboardAbout               = "clipboard.about"
        case clipboardQuit                = "clipboard.quit"
        case clipboardPasteStackTitle     = "clipboard.pasteStack.title"
        case clipboardPasteStackRemove    = "clipboard.pasteStack.remove"
        case previewTitle                 = "preview.title"
        case previewEmpty                 = "preview.empty"
        case previewImage                 = "preview.image"
        case previewText                  = "preview.text"
        case previewRichText              = "preview.richText"
        case previewFile                  = "preview.file"
        case previewColor                 = "preview.color"
        case previewLink                  = "preview.link"
        case previewCode                  = "preview.code"
        case previewImageFailed           = "preview.image.failed"
        case previewUnknownApp            = "preview.unknownApp"
        case previewFirstCopyTime         = "preview.firstCopyTime"
        case previewLastCopyTime          = "preview.lastCopyTime"
        case previewShortcutPin           = "preview.shortcut.pin"
        case previewShortcutDelete        = "preview.shortcut.delete"
        case systemPermissions            = "permissions.menu.title"
        case inputMonitoringSetting       = "permissions.action.input_monitoring"
        case accessibilitySetting         = "permissions.action.accessibility"
        case toolsAndLogs                 = "tools.menu.title"
        case openLogFile                  = "tools.action.open_log"
        case clearLogs                    = "tools.action.clear_log"
        case languageMenu                 = "language.menu.title"
        case languageOptionVietnamese     = "language.option.vietnamese"
        case languageOptionEnglish        = "language.option.english"
        case languageOptionSystem         = "language.option.system"
        case tooltipVietnamese            = "tooltip.vietnamese"
        case tooltipEnglish               = "tooltip.english"
        case quitApp                      = "app.action.quit"
    }
}

// MARK: - Global Helpers

public func L10n(_ key: LocalizationService.StringKey) -> String {
    LocalizationService.shared.string(for: key)
}

public func L10n(_ key: String) -> String {
    LocalizationService.shared.string(for: key)
}

extension Notification.Name {
    public static let languageDidChange = Notification.Name("SKeyLanguageDidChangeNotification")
    public static let skeyLanguageDidChange = Notification.Name("SKeyLanguageDidChangeNotification")
}
