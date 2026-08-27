import Foundation

// MARK: - Notification Extension

extension Notification.Name {
    public static let skeyLanguageDidChange = Notification.Name("com.nam088.skey.languageDidChange")
}

// MARK: - LocalizationService

/// Apple-recommended localization manager supporting dynamic locale bundle loading
public final class LocalizationService {
    public static let shared = LocalizationService()

    private let defaults = UserDefaults.standard
    private let kAppLanguageKey = "SKey_AppLanguage"

    private var cachedBundle: Bundle?
    private var cachedLanguage: AppLanguage?

    public var currentLanguage: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: kAppLanguageKey),
                  let lang = AppLanguage(rawValue: raw) else {
                return .vietnamese
            }
            return lang
        }
        set {
            defaults.set(newValue.rawValue, forKey: kAppLanguageKey)
            cachedBundle = nil
            cachedLanguage = nil
            NotificationCenter.default.post(name: .skeyLanguageDidChange, object: nil)
        }
    }

    private init() {}

    public var activeLocaleIdentifier: String {
        switch currentLanguage {
        case .vietnamese:
            return "vi"
        case .english:
            return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "vi"
            return preferred.starts(with: "vi") ? "vi" : "en"
        }
    }

    public var isVietnameseLocale: Bool {
        activeLocaleIdentifier == "vi"
    }

    /// Dynamic localized bundle loader conforming to Apple standards
    public var localizedBundle: Bundle {
        if let cached = cachedBundle, cachedLanguage == currentLanguage {
            return cached
        }

        let code = activeLocaleIdentifier
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            cachedBundle = bundle
            cachedLanguage = currentLanguage
            return bundle
        }

        return Bundle.main
    }

    // MARK: - Localized String Resolution

    public func string(for key: StringKey) -> String {
        let bundle = localizedBundle
        let rawKey = key.rawValue
        let fallback = defaultFallback(for: key)
        return bundle.localizedString(forKey: rawKey, value: fallback, table: "Localizable")
    }

    private func defaultFallback(for key: StringKey) -> String {
        let isVn = isVietnameseLocale
        switch key {
        case .appTitle:
            return "SKey"
        case .toggleLanguage:
            return isVn ? "Chuyển Tiếng Việt/Anh (Opt+Z)" : "Toggle Vietnamese/English (Opt+Z)"
        case .inputMethodMenu:
            return isVn ? "Kiểu gõ" : "Input Method"
        case .spellCheck:
            return isVn ? "Kiểm tra chính tả" : "Spell Check"
        case .freeMarking:
            return isVn ? "Bỏ dấu tự do" : "Free Marking"
        case .modernStyle:
            return isVn ? "Đặt dấu kiểu mới (oà, uỳ)" : "Modern Accent Style (oà, uỳ)"
        case .smartAppSwitch:
            return isVn ? "Tự động đổi Tiếng Anh khi vào IDE/Terminal" : "Smart App Switch (IDE/Terminal -> English)"
        case .advancedOptions:
            return isVn ? "Tùy chọn nâng cao" : "Advanced Options"
        case .quickTelex:
            return isVn ? "Gõ nhanh Telex (cc->ch, gg->gi, uu->ươ)" : "Quick Telex (cc->ch, gg->gi, uu->ươ)"
        case .quickStartConsonant:
            return isVn ? "Gõ nhanh phụ âm đầu (f->ph, j->gi, w->qu)" : "Quick Initial Consonant (f->ph, j->gi, w->qu)"
        case .quickEndConsonant:
            return isVn ? "Gõ nhanh phụ âm cuối (g->ng, h->nh, k->ch)" : "Quick Final Consonant (g->ng, h->nh, k->ch)"
        case .upperCaseFirstChar:
            return isVn ? "Tự động viết hoa đầu câu" : "Capitalize First Letter of Sentences"
        case .swallowedKeyRestore:
            return isVn ? "Khôi phục phím bị nuốt từ tiếng Anh" : "Restore Swallowed English Keys"
        case .clipboardMenu:
            return isVn ? "Lịch sử Clipboard (Maccy)" : "Clipboard History (Maccy)"
        case .clipboardEmpty:
            return isVn ? "Chưa có lịch sử copy" : "No copy history"
        case .clearClipboard:
            return isVn ? "Xóa toàn bộ lịch sử" : "Clear All History"
        case .systemPermissions:
            return isVn ? "Cấp quyền hệ thống (Bắt buộc)" : "System Permissions (Required)"
        case .inputMonitoringSetting:
            return isVn ? "Mở cài đặt Theo dõi đầu vào (Input Monitoring)..." : "Open Input Monitoring Settings..."
        case .accessibilitySetting:
            return isVn ? "Mở cài đặt Trợ năng (Accessibility)..." : "Open Accessibility Settings..."
        case .toolsAndLogs:
            return isVn ? "Công cụ & Nhật ký (Logs)" : "Tools & Logs"
        case .openLogFile:
            return isVn ? "Mở file nhật ký (/tmp/skey.log)..." : "Open Log File (/tmp/skey.log)..."
        case .clearLogs:
            return isVn ? "Xóa sạch bộ đệm nhật ký" : "Clear Log Buffer"
        case .languageMenu:
            return isVn ? "Ngôn ngữ giao diện" : "Interface Language"
        case .tooltipVietnamese:
            return isVn
                ? "SKey: Tiếng Việt (Click để chuyển sang Anh, chuột phải xem menu)"
                : "SKey: Vietnamese (Click to switch to English, right-click for menu)"
        case .tooltipEnglish:
            return isVn
                ? "SKey: Tiếng Anh (Click để chuyển sang Việt, chuột phải xem menu)"
                : "SKey: English (Click to switch to Vietnamese, right-click for menu)"
        case .languageOptionVietnamese:
            return "Tiếng Việt"
        case .languageOptionEnglish:
            return "English"
        case .languageOptionSystem:
            return isVn ? "Theo hệ thống" : "System Default"
        case .quitApp:
            return isVn ? "Thoát SKey" : "Quit SKey"
        }
    }

    public enum StringKey: String {
        case appTitle                 = "app.title"
        case toggleLanguage           = "keyboard.menu.toggle"
        case inputMethodMenu          = "keyboard.menu.input_method"
        case spellCheck               = "keyboard.options.spell_check"
        case freeMarking              = "keyboard.options.free_marking"
        case modernStyle              = "keyboard.options.modern_style"
        case smartAppSwitch           = "keyboard.options.smart_switch"
        case advancedOptions          = "keyboard.options.advanced"
        case quickTelex               = "keyboard.advanced.quick_telex"
        case quickStartConsonant      = "keyboard.advanced.quick_start_consonant"
        case quickEndConsonant        = "keyboard.advanced.quick_end_consonant"
        case upperCaseFirstChar       = "keyboard.advanced.upper_case_first"
        case swallowedKeyRestore      = "keyboard.advanced.swallowed_restore"
        case clipboardMenu            = "clipboard.menu.title"
        case clipboardEmpty           = "clipboard.status.empty"
        case clearClipboard           = "clipboard.action.clear_all"
        case systemPermissions        = "permissions.menu.title"
        case inputMonitoringSetting   = "permissions.action.input_monitoring"
        case accessibilitySetting     = "permissions.action.accessibility"
        case toolsAndLogs             = "tools.menu.title"
        case openLogFile              = "tools.action.open_log"
        case clearLogs                = "tools.action.clear_log"
        case languageMenu             = "language.menu.title"
        case languageOptionVietnamese = "language.option.vietnamese"
        case languageOptionEnglish    = "language.option.english"
        case languageOptionSystem     = "language.option.system"
        case tooltipVietnamese        = "tooltip.vietnamese"
        case tooltipEnglish           = "tooltip.english"
        case quitApp                  = "app.action.quit"
    }
}

// MARK: - Global Helper

public func L10n(_ key: LocalizationService.StringKey) -> String {
    LocalizationService.shared.string(for: key)
}
