import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - SKeyBackupData Model

public struct SKeyBackupData: Codable {
    public var app: String = "SKey"
    public var version: String = "1.0.0"
    public var exportedAt: Date = Date()
    public var keyboard: KeyboardData
    public var clipboard: ClipboardData
    public var macro: MacroData
    public var general: GeneralData

    public struct KeyboardData: Codable {
        public var isVietnamese: Bool
        public var inputMethod: Int32
        public var charset: String
        public var spellCheck: Bool
        public var freeMarking: Bool
        public var modernStyle: Bool
        public var quickTelex: Bool
        public var quickStartConsonant: Bool
        public var quickEndConsonant: Bool
        public var upperCaseFirstChar: Bool
        public var swallowedKeyRestore: Bool
        public var allowConsonantZFWJ: Bool
        public var smartAppSwitchEnabled: Bool
    }

    public struct ClipboardData: Codable {
        public var isEnabled: Bool
        public var historyLimit: Int
        public var searchMode: String
        public var autoPaste: Bool
        public var pasteAsPlainText: Bool
        public var saveText: Bool
        public var saveImages: Bool
        public var showApplicationIcons: Bool
        public var showHexColorSwatch: Bool
        public var showFooter: Bool
        public var showTitle: Bool
        public var suppressClearAlert: Bool
        public var openPreviewAutomatically: Bool
        public var previewDelayMilliseconds: Int
        public var imageThumbnailHeight: Int
        public var pinTo: String
        public var sortOrder: String
        public var highlightMatch: String
        public var popupPosition: String
    }

    public struct MacroData: Codable {
        public var isEnabled: Bool
        public var autoCaps: Bool
        public var inEnglishMode: Bool
        public var items: [MacroItem]
    }

    public struct GeneralData: Codable {
        public var launchAtLogin: Bool
        public var appLanguage: String
        public var checkUpdates: Bool
    }
}

// MARK: - SettingsBackupManager

public final class SettingsBackupManager {
    public static let shared = SettingsBackupManager()

    private init() {}

    /// Capture current snapshot of all SKey settings
    public func createBackupSnapshot() -> SKeyBackupData {
        let app = AppSettings.shared

        let kbData = SKeyBackupData.KeyboardData(
            isVietnamese: app.keyboard.isVietnamese,
            inputMethod: app.keyboard.inputMethodRawValue,
            charset: app.keyboard.charset,
            spellCheck: app.keyboard.spellCheck,
            freeMarking: app.keyboard.freeMarking,
            modernStyle: app.keyboard.modernStyle,
            quickTelex: app.keyboard.quickTelex,
            quickStartConsonant: app.keyboard.quickStartConsonant,
            quickEndConsonant: app.keyboard.quickEndConsonant,
            upperCaseFirstChar: app.keyboard.upperCaseFirstChar,
            swallowedKeyRestore: app.keyboard.swallowedKeyRestore,
            allowConsonantZFWJ: app.keyboard.allowConsonantZFWJ,
            smartAppSwitchEnabled: app.keyboard.smartAppSwitchEnabled
        )

        let cbData = SKeyBackupData.ClipboardData(
            isEnabled: app.clipboard.isEnabled,
            historyLimit: app.clipboard.historyLimit,
            searchMode: app.clipboard.searchMode,
            autoPaste: app.clipboard.autoPaste,
            pasteAsPlainText: app.clipboard.pasteAsPlainText,
            saveText: app.clipboard.saveText,
            saveImages: app.clipboard.saveImages,
            showApplicationIcons: app.clipboard.showApplicationIcons,
            showHexColorSwatch: app.clipboard.showHexColorSwatch,
            showFooter: app.clipboard.showFooter,
            showTitle: app.clipboard.showTitle,
            suppressClearAlert: app.clipboard.suppressClearAlert,
            openPreviewAutomatically: app.clipboard.openPreviewAutomatically,
            previewDelayMilliseconds: app.clipboard.previewDelayMilliseconds,
            imageThumbnailHeight: app.clipboard.imageThumbnailHeight,
            pinTo: app.clipboard.pinTo.rawValue,
            sortOrder: app.clipboard.sortOrder.rawValue,
            highlightMatch: app.clipboard.highlightMatch.rawValue,
            popupPosition: app.clipboard.popupPosition.rawValue
        )

        let macroData = SKeyBackupData.MacroData(
            isEnabled: app.macro.isEnabled,
            autoCaps: app.macro.autoCaps,
            inEnglishMode: app.macro.inEnglishMode,
            items: app.macro.items
        )

        let genData = SKeyBackupData.GeneralData(
            launchAtLogin: app.general.launchAtLogin,
            appLanguage: app.general.appLanguage,
            checkUpdates: app.general.checkUpdates
        )

        return SKeyBackupData(
            keyboard: kbData,
            clipboard: cbData,
            macro: macroData,
            general: genData
        )
    }

    /// Export snapshot to a user-selected JSON file
    public func exportSettings(completion: @escaping (Bool) -> Void) {
        let snapshot = createBackupSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot) else {
            completion(false)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = L10n("general.option.exportSettings")
        savePanel.nameFieldStringValue = "skey_backup_\(formattedDateForFilename()).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try data.write(to: url, options: .atomic)
                completion(true)
            } catch {
                skeyLog("[Backup] Export failed: \(error.localizedDescription)", category: .general)
                completion(false)
            }
        } else {
            completion(false)
        }
    }

    /// Import snapshot from user-selected JSON file and apply to AppSettings
    public func importSettings(completion: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = L10n("general.option.importSettings")
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(SKeyBackupData.self, from: data)

                applyBackup(backup)
                completion(true)
            } catch {
                skeyLog("[Backup] Import failed: \(error.localizedDescription)", category: .general)
                completion(false)
            }
        } else {
            completion(false)
        }
    }

    /// Apply backup data to all modules
    public func applyBackup(_ backup: SKeyBackupData) {
        let app = AppSettings.shared

        // 1. Keyboard
        app.keyboard.isVietnamese = backup.keyboard.isVietnamese
        app.keyboard.inputMethodRawValue = backup.keyboard.inputMethod
        app.keyboard.charset = backup.keyboard.charset
        app.keyboard.spellCheck = backup.keyboard.spellCheck
        app.keyboard.freeMarking = backup.keyboard.freeMarking
        app.keyboard.modernStyle = backup.keyboard.modernStyle
        app.keyboard.quickTelex = backup.keyboard.quickTelex
        app.keyboard.quickStartConsonant = backup.keyboard.quickStartConsonant
        app.keyboard.quickEndConsonant = backup.keyboard.quickEndConsonant
        app.keyboard.upperCaseFirstChar = backup.keyboard.upperCaseFirstChar
        app.keyboard.swallowedKeyRestore = backup.keyboard.swallowedKeyRestore
        app.keyboard.allowConsonantZFWJ = backup.keyboard.allowConsonantZFWJ
        app.keyboard.smartAppSwitchEnabled = backup.keyboard.smartAppSwitchEnabled

        // Sync with low-level engine
        EventTapManager.shared.setLanguage(vietnamese: backup.keyboard.isVietnamese)
        EventTapManager.shared.engine.setInputMethod(app.keyboard.inputMethod)
        EventTapManager.shared.engine.setSpellCheck(backup.keyboard.spellCheck)
        EventTapManager.shared.engine.setFreeMarking(backup.keyboard.freeMarking)
        EventTapManager.shared.engine.setModernStyle(backup.keyboard.modernStyle)
        EventTapManager.shared.engine.setQuickTelex(backup.keyboard.quickTelex)
        EventTapManager.shared.engine.setQuickStartConsonant(backup.keyboard.quickStartConsonant)
        EventTapManager.shared.engine.setQuickEndConsonant(backup.keyboard.quickEndConsonant)
        EventTapManager.shared.engine.setUpperCaseFirstChar(backup.keyboard.upperCaseFirstChar)
        EventTapManager.shared.engine.setSwallowedKeyRestore(backup.keyboard.swallowedKeyRestore)
        EventTapManager.shared.engine.setAllowConsonantZFWJ(backup.keyboard.allowConsonantZFWJ)

        // 2. Clipboard
        app.clipboard.isEnabled = backup.clipboard.isEnabled
        app.clipboard.historyLimit = backup.clipboard.historyLimit
        app.clipboard.searchMode = backup.clipboard.searchMode
        app.clipboard.autoPaste = backup.clipboard.autoPaste
        app.clipboard.pasteAsPlainText = backup.clipboard.pasteAsPlainText
        app.clipboard.saveText = backup.clipboard.saveText
        app.clipboard.saveImages = backup.clipboard.saveImages
        app.clipboard.showApplicationIcons = backup.clipboard.showApplicationIcons
        app.clipboard.showHexColorSwatch = backup.clipboard.showHexColorSwatch
        app.clipboard.showFooter = backup.clipboard.showFooter
        app.clipboard.showTitle = backup.clipboard.showTitle
        app.clipboard.suppressClearAlert = backup.clipboard.suppressClearAlert
        app.clipboard.openPreviewAutomatically = backup.clipboard.openPreviewAutomatically
        app.clipboard.previewDelayMilliseconds = backup.clipboard.previewDelayMilliseconds
        app.clipboard.imageThumbnailHeight = backup.clipboard.imageThumbnailHeight
        if let pin = ClipboardPinTo(rawValue: backup.clipboard.pinTo) { app.clipboard.pinTo = pin }
        if let sort = ClipboardSortOrder(rawValue: backup.clipboard.sortOrder) { app.clipboard.sortOrder = sort }
        if let hl = HighlightMatchStyle(rawValue: backup.clipboard.highlightMatch) { app.clipboard.highlightMatch = hl }
        if let pos = ClipboardPopupPosition(rawValue: backup.clipboard.popupPosition) { app.clipboard.popupPosition = pos }

        // 3. Macro
        app.macro.isEnabled = backup.macro.isEnabled
        app.macro.autoCaps = backup.macro.autoCaps
        app.macro.inEnglishMode = backup.macro.inEnglishMode
        app.macro.items = backup.macro.items
        MacroEngine.shared.reloadMacros()

        // 4. General
        app.general.launchAtLogin = backup.general.launchAtLogin
        app.general.checkUpdates = backup.general.checkUpdates
        if let lang = AppLanguage(rawValue: backup.general.appLanguage) {
            LocalizationService.shared.currentLanguage = lang
        }

        skeyLog("[Backup] Successfully imported settings snapshot", category: .general)
    }

    private func formattedDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
