import AppKit
import Foundation
import os

// MARK: - MacroMatchResult

public struct MacroMatchResult {
    public let handled: Bool
    public let backspaces: Int
    public let replacement: String

    public static let unhandled = MacroMatchResult(handled: false, backspaces: 0, replacement: "")
}

// MARK: - MacroEngine

/// High-performance $O(1)$ in-memory macro expander for typing shortcuts
public final class MacroEngine: @unchecked Sendable {
    public static let shared = MacroEngine()

    private var lock = os_unfair_lock_s()
    private var macroMap: [String: String] = [:]
    private var constantMap: [String: String] = [:]
    private var currentWord: [Character] = []

    private init() {
        reloadMacros()
    }

    public func reloadMacros() {
        let items = AppSettings.shared.macro.items
        var newMap: [String: String] = [:]
        for item in items {
            let key = item.shortcut
                .precomposedStringWithCanonicalMapping
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                newMap[key] = item.replacement
            }
        }

        let constants = AppSettings.shared.macro.constants
        var newConstantMap: [String: String] = [:]
        for c in constants {
            let k = c.key
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
                .replacingOccurrences(of: "$", with: "")
                .lowercased()
            if !k.isEmpty {
                newConstantMap[k] = c.value
            }
        }

        os_unfair_lock_lock(&lock)
        macroMap = newMap
        constantMap = newConstantMap
        os_unfair_lock_unlock(&lock)
    }

    // MARK: - Word Buffer Tracking

    public func reset() {
        os_unfair_lock_lock(&lock)
        currentWord.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&lock)
    }

    public func recordChar(_ char: Character) {
        os_unfair_lock_lock(&lock)
        if char.isWhitespace || char.isNewline {
            currentWord.removeAll(keepingCapacity: true)
        } else {
            currentWord.append(char)
            if currentWord.count > 64 {
                currentWord.removeFirst()
            }
        }
        os_unfair_lock_unlock(&lock)
    }

    public func recordTransform(backspaces: Int, text: String) {
        os_unfair_lock_lock(&lock)
        let removeCount = min(backspaces, currentWord.count)
        if removeCount > 0 {
            currentWord.removeLast(removeCount)
        }
        for char in text {
            if char.isWhitespace || char.isNewline {
                currentWord.removeAll(keepingCapacity: true)
            } else {
                currentWord.append(char)
                if currentWord.count > 64 {
                    currentWord.removeFirst()
                }
            }
        }
        os_unfair_lock_unlock(&lock)
    }

    public func recordBackspace() {
        os_unfair_lock_lock(&lock)
        if !currentWord.isEmpty {
            currentWord.removeLast()
        }
        os_unfair_lock_unlock(&lock)
    }

    // MARK: - Macro Expansion on Space

    public func evaluateMacroOnSpace() -> MacroMatchResult {
        guard AppSettings.shared.macro.isEnabled else {
            reset()
            return .unhandled
        }

        os_unfair_lock_lock(&lock)
        defer {
            currentWord.removeAll(keepingCapacity: true)
            os_unfair_lock_unlock(&lock)
        }

        guard !currentWord.isEmpty else { return .unhandled }

        let typedString = String(currentWord).precomposedStringWithCanonicalMapping
        let lookupKey = typedString.lowercased()

        var rawReplacement: String? = macroMap[lookupKey]

        // Direct constant expansion with custom prefix (e.g. :email, $email, ;email)
        let macroSettings = AppSettings.shared.macro
        if rawReplacement == nil && macroSettings.directConstantsEnabled {
            let prefix = macroSettings.constantPrefix
            if !prefix.isEmpty && typedString.hasPrefix(prefix) && typedString.count > prefix.count {
                let constantKey = String(typedString.dropFirst(prefix.count)).lowercased()
                if let constVal = constantMap[constantKey] {
                    rawReplacement = constVal
                }
            }
        }

        guard let rawReplacement = rawReplacement else {
            return .unhandled
        }

        let backspaces = currentWord.count
        var transformedReplacement = rawReplacement

        // Auto-Caps handling
        if AppSettings.shared.macro.autoCaps {
            if typedString.allSatisfy({ $0.isUppercase }) && typedString.count > 1 {
                transformedReplacement = rawReplacement.uppercased()
            } else if let firstChar = typedString.first, firstChar.isUppercase {
                transformedReplacement = rawReplacement.prefix(1).uppercased() + rawReplacement.dropFirst()
            }
        }

        // Dynamic variables resolution ({date}, {time}, {datetime}, {clipboard}, {$constants})
        let currentConstants = constantMap
        transformedReplacement = resolveDynamicVariables(transformedReplacement, constants: currentConstants)

        let finalReplacement = transformedReplacement.hasSuffix(" ") ? transformedReplacement : (transformedReplacement + " ")
        return MacroMatchResult(
            handled: true,
            backspaces: backspaces,
            replacement: finalReplacement
        )
    }

    /// Previews the dynamic expansion of text without mutating any engine state
    public func previewExpansion(for text: String) -> String {
        os_unfair_lock_lock(&lock)
        let currentConstants = constantMap
        os_unfair_lock_unlock(&lock)
        return resolveDynamicVariables(text, constants: currentConstants)
    }

    /// Evaluates if a shortcut matches and returns the simulated expansion
    public func testExpand(shortcut: String) -> String? {
        let key = shortcut.precomposedStringWithCanonicalMapping
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        os_unfair_lock_lock(&lock)
        var raw = macroMap[key]
        let currentConstants = constantMap
        let macroSettings = AppSettings.shared.macro
        if raw == nil && macroSettings.directConstantsEnabled {
            let prefix = macroSettings.constantPrefix
            if !prefix.isEmpty && key.hasPrefix(prefix.lowercased()) && key.count > prefix.count {
                let constKey = String(key.dropFirst(prefix.count))
                raw = currentConstants[constKey]
            }
        }
        os_unfair_lock_unlock(&lock)
        guard let raw = raw else { return nil }
        return resolveDynamicVariables(raw, constants: currentConstants)
    }

    private func resolveDynamicVariables(_ text: String, constants: [String: String]) -> String {
        guard AppSettings.shared.macro.dynamicVariablesEnabled else { return text }
        guard text.contains("{") && text.contains("}") else { return text }

        var result = text
        let now = Date()

        // 1. Built-in Dynamic Variables
        if result.range(of: "{date}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            result = replaceCaseInsensitive(in: result, token: "{date}", with: formatter.string(from: now))
        }
        if result.range(of: "{time}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            result = replaceCaseInsensitive(in: result, token: "{time}", with: formatter.string(from: now))
        }
        if result.range(of: "{datetime}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
            result = replaceCaseInsensitive(in: result, token: "{datetime}", with: formatter.string(from: now))
        }
        if result.range(of: "{year}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            result = replaceCaseInsensitive(in: result, token: "{year}", with: formatter.string(from: now))
        }
        if result.range(of: "{month}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM"
            result = replaceCaseInsensitive(in: result, token: "{month}", with: formatter.string(from: now))
        }
        if result.range(of: "{day}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd"
            result = replaceCaseInsensitive(in: result, token: "{day}", with: formatter.string(from: now))
        }
        if result.range(of: "{weekday}", options: .caseInsensitive) != nil {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: LocalizationService.shared.currentLanguage.rawValue)
            formatter.dateFormat = "EEEE"
            result = replaceCaseInsensitive(in: result, token: "{weekday}", with: formatter.string(from: now))
        }
        if result.range(of: "{timestamp}", options: .caseInsensitive) != nil {
            let ts = String(Int(now.timeIntervalSince1970))
            result = replaceCaseInsensitive(in: result, token: "{timestamp}", with: ts)
        }
        if result.range(of: "{uuid}", options: .caseInsensitive) != nil {
            result = replaceCaseInsensitive(in: result, token: "{uuid}", with: UUID().uuidString.lowercased())
        }
        if result.range(of: "{guid}", options: .caseInsensitive) != nil {
            result = replaceCaseInsensitive(in: result, token: "{guid}", with: UUID().uuidString.uppercased())
        }
        if result.range(of: "{clipboard}", options: .caseInsensitive) != nil {
            let clip = NSPasteboard.general.string(forType: .string) ?? ""
            result = replaceCaseInsensitive(in: result, token: "{clipboard}", with: clip)
        }

        // 2. User-Defined Custom Constants: {$constant_name}
        // Zero lag: only scans if the string contains the special "{$" token prefix!
        if result.contains("{$") {
            for (k, v) in constants {
                let token = "{$" + k + "}"
                if result.range(of: token, options: .caseInsensitive) != nil {
                    // Constant values can recursively use dynamic variables
                    let resolvedVal = resolveDynamicVariables(v, constants: constants)
                    result = replaceCaseInsensitive(in: result, token: token, with: resolvedVal)
                }
            }
        }

        return result
    }

    private func replaceCaseInsensitive(in text: String, token: String, with replacement: String) -> String {
        var str = text
        while let range = str.range(of: token, options: .caseInsensitive) {
            str.replaceSubrange(range, with: replacement)
        }
        return str
    }
}
