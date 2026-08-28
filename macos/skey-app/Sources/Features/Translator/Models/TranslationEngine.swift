import Foundation
import SwiftUI

// MARK: - Translation Engine Type

public enum TranslationEngineType: String, CaseIterable, Identifiable, Codable {
    case google = "google"
    case apple = "apple"
    case gemini = "gemini"
    case deepl = "deepl"
    case groq = "groq"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .google: return L10n("engine.google.name")
        case .apple:  return L10n("engine.apple.name")
        case .gemini: return L10n("engine.gemini.name")
        case .deepl:  return L10n("engine.deepl.name")
        case .groq:   return L10n("engine.groq.name")
        }
    }

    public var subtitle: String {
        switch self {
        case .google: return L10n("engine.google.desc")
        case .apple:  return L10n("engine.apple.desc")
        case .gemini: return L10n("engine.gemini.desc")
        case .deepl:  return L10n("engine.deepl.desc")
        case .groq:   return L10n("engine.groq.desc")
        }
    }

    public var icon: String {
        switch self {
        case .google: return "globe.asia.australia.fill"
        case .apple:  return "apple.logo"
        case .gemini: return "sparkles"
        case .deepl:  return "text.bubble.fill"
        case .groq:   return "bolt.fill"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .google: return .blue
        case .apple:  return .gray
        case .gemini: return .purple
        case .deepl:  return .cyan
        case .groq:   return .orange
        }
    }

    public var isFreeNoKeyRequired: Bool {
        switch self {
        case .google, .apple: return true
        case .gemini, .deepl, .groq: return false
        }
    }
}

// MARK: - Translation Engine Config

public struct TranslationEngineConfig: Identifiable, Codable, Equatable {
    public var id: String { type.rawValue }
    public var type: TranslationEngineType
    public var isEnabled: Bool
    public var apiKey: String

    public init(type: TranslationEngineType, isEnabled: Bool = true, apiKey: String = "") {
        self.type = type
        self.isEnabled = isEnabled
        self.apiKey = apiKey
    }

    public static var defaultList: [TranslationEngineConfig] {
        [
            TranslationEngineConfig(type: .google, isEnabled: true),
            TranslationEngineConfig(type: .apple, isEnabled: true),
            TranslationEngineConfig(type: .gemini, isEnabled: true),
            TranslationEngineConfig(type: .deepl, isEnabled: true),
            TranslationEngineConfig(type: .groq, isEnabled: true)
        ]
    }
}
