import Combine
import Foundation

// MARK: - Clipboard Enums for Settings

public enum ClipboardSortOrder: String, Codable, CaseIterable, Sendable {
    case lastCopiedAt
    case firstCopiedAt
    case numberOfCopies
}

public enum ClipboardPopupPosition: String, Codable, CaseIterable, Sendable {
    case cursor
    case statusItem
}

public enum ClipboardPinTo: String, Codable, CaseIterable, Sendable {
    case top
    case bottom
}

public enum HighlightMatchStyle: String, Codable, CaseIterable, Sendable {
    case color
    case bold
    case italic
    case underline
}

// MARK: - ClipboardSettings

public final class ClipboardSettings: NSObject, SettingsModule {
    public static let prefix = "SKey_Clipboard_"
    private let storage: SettingsStorage

    public enum Keys {
        public static let isEnabled                 = "SKey_ClipboardEnabled"
        public static let historyLimit              = "SKey_ClipboardLimit"
        public static let searchMode                = "SKey_ClipboardSearchMode"
        public static let autoPaste                 = "SKey_ClipboardAutoPaste"
        public static let pasteAsPlainText          = "SKey_ClipboardPastePlainText"
        public static let saveText                  = "SKey_ClipboardSaveText"
        public static let saveImages                = "SKey_ClipboardSaveImages"
        public static let showApplicationIcons      = "SKey_ClipboardShowAppIcons"
        public static let showHexColorSwatch        = "SKey_ClipboardShowHexColorSwatch"
        public static let showFooter                = "SKey_ClipboardShowFooter"
        public static let showTitle                 = "SKey_ClipboardShowTitle"
        public static let suppressClearAlert        = "SKey_ClipboardSuppressClearAlert"
        public static let openPreviewAutomatically  = "SKey_ClipboardOpenPreviewAuto"
        public static let previewDelayMilliseconds  = "SKey_ClipboardPreviewDelayMs"
        public static let imageThumbnailHeight      = "SKey_ClipboardImageThumbHeight"
        public static let pinTo                     = "SKey_ClipboardPinTo"
        public static let sortOrder                 = "SKey_ClipboardSortOrder"
        public static let highlightMatch            = "SKey_ClipboardHighlightMatch"
        public static let popupPosition             = "SKey_ClipboardPopupPosition"
        public static let autoExpireOTP             = "SKey_ClipboardAutoExpireOTP"
    }

    public init(storage: SettingsStorage = .shared) {
        self.storage = storage
        super.init()
        registerDefaults(in: storage)
    }

    public func registerDefaults(in storage: SettingsStorage) {
        storage.registerDefaults([
            Keys.isEnabled:                 true,
            Keys.historyLimit:              100,
            Keys.searchMode:                "Fuzzy",
            Keys.autoPaste:                 true,
            Keys.pasteAsPlainText:          true,
            Keys.saveText:                  true,
            Keys.saveImages:                true,
            Keys.showApplicationIcons:       true,
            Keys.showHexColorSwatch:         true,
            Keys.showFooter:                 true,
            Keys.showTitle:                  false,
            Keys.suppressClearAlert:         false,
            Keys.openPreviewAutomatically:   true,
            Keys.previewDelayMilliseconds:   250,
            Keys.imageThumbnailHeight:       40,
            Keys.pinTo:                      ClipboardPinTo.top.rawValue,
            Keys.sortOrder:                  ClipboardSortOrder.lastCopiedAt.rawValue,
            Keys.highlightMatch:             HighlightMatchStyle.color.rawValue,
            Keys.popupPosition:              ClipboardPopupPosition.cursor.rawValue,
            Keys.autoExpireOTP:              true
        ])
    }

    public func resetToDefaults() {
        objectWillChange.send()
        for key in [
            Keys.isEnabled, Keys.historyLimit, Keys.searchMode, Keys.autoPaste,
            Keys.pasteAsPlainText, Keys.saveText, Keys.saveImages,
            Keys.showApplicationIcons, Keys.showHexColorSwatch, Keys.showFooter,
            Keys.showTitle, Keys.suppressClearAlert, Keys.openPreviewAutomatically,
            Keys.previewDelayMilliseconds, Keys.imageThumbnailHeight,
            Keys.pinTo, Keys.sortOrder, Keys.highlightMatch, Keys.popupPosition
        ] {
            storage.removeObject(forKey: key)
        }
    }

    public var isEnabled: Bool {
        get { storage.bool(forKey: Keys.isEnabled, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.isEnabled)
        }
    }

    public var historyLimit: Int {
        get { storage.integer(forKey: Keys.historyLimit, default: 100) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.historyLimit)
        }
    }

    public var searchMode: String {
        get { storage.string(forKey: Keys.searchMode, default: "Fuzzy") }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.searchMode)
        }
    }

    public var autoPaste: Bool {
        get { storage.bool(forKey: Keys.autoPaste, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.autoPaste)
        }
    }

    public var pasteAsPlainText: Bool {
        get { storage.bool(forKey: Keys.pasteAsPlainText, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.pasteAsPlainText)
        }
    }

    public var saveText: Bool {
        get { storage.bool(forKey: Keys.saveText, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.saveText)
        }
    }

    public var saveImages: Bool {
        get { storage.bool(forKey: Keys.saveImages, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.saveImages)
        }
    }

    public var showApplicationIcons: Bool {
        get { storage.bool(forKey: Keys.showApplicationIcons, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.showApplicationIcons)
        }
    }

    public var showHexColorSwatch: Bool {
        get { storage.bool(forKey: Keys.showHexColorSwatch, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.showHexColorSwatch)
        }
    }

    public var showFooter: Bool {
        get { storage.bool(forKey: Keys.showFooter, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.showFooter)
        }
    }

    public var showTitle: Bool {
        get { storage.bool(forKey: Keys.showTitle, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.showTitle)
        }
    }

    public var suppressClearAlert: Bool {
        get { storage.bool(forKey: Keys.suppressClearAlert, default: false) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.suppressClearAlert)
        }
    }

    public var openPreviewAutomatically: Bool {
        get { storage.bool(forKey: Keys.openPreviewAutomatically, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.openPreviewAutomatically)
        }
    }

    public var previewDelayMilliseconds: Int {
        get {
            let val = storage.integer(forKey: Keys.previewDelayMilliseconds, default: 250)
            return val > 0 ? val : 250
        }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.previewDelayMilliseconds)
        }
    }

    public var imageThumbnailHeight: Int {
        get { storage.integer(forKey: Keys.imageThumbnailHeight, default: 40) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.imageThumbnailHeight)
        }
    }

    public var pinTo: ClipboardPinTo {
        get {
            let raw = storage.string(forKey: Keys.pinTo, default: ClipboardPinTo.top.rawValue)
            return ClipboardPinTo(rawValue: raw) ?? .top
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Keys.pinTo)
        }
    }

    public var sortOrder: ClipboardSortOrder {
        get {
            let raw = storage.string(forKey: Keys.sortOrder, default: ClipboardSortOrder.lastCopiedAt.rawValue)
            return ClipboardSortOrder(rawValue: raw) ?? .lastCopiedAt
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Keys.sortOrder)
        }
    }

    public var highlightMatch: HighlightMatchStyle {
        get {
            let raw = storage.string(forKey: Keys.highlightMatch, default: HighlightMatchStyle.color.rawValue)
            return HighlightMatchStyle(rawValue: raw) ?? .color
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Keys.highlightMatch)
        }
    }

    public var popupPosition: ClipboardPopupPosition {
        get {
            let raw = storage.string(forKey: Keys.popupPosition, default: ClipboardPopupPosition.cursor.rawValue)
            return ClipboardPopupPosition(rawValue: raw) ?? .cursor
        }
        set {
            objectWillChange.send()
            storage.set(newValue.rawValue, forKey: Keys.popupPosition)
        }
    }

    public var autoExpireOTP: Bool {
        get { storage.bool(forKey: Keys.autoExpireOTP, default: true) }
        set {
            objectWillChange.send()
            storage.set(newValue, forKey: Keys.autoExpireOTP)
        }
    }
}
