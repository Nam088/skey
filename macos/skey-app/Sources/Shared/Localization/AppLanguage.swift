import Foundation

// MARK: - AppLanguage

public enum AppLanguage: String, CaseIterable, Codable {
    case vietnamese = "vi"
    case english    = "en"
    case system     = "system"

    public var displayName: String {
        switch self {
        case .vietnamese: return L10n(.languageOptionVietnamese)
        case .english:    return L10n(.languageOptionEnglish)
        case .system:     return L10n(.languageOptionSystem)
        }
    }
}
