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
    private var currentWord: [Character] = []

    private init() {
        reloadMacros()
    }

    public func reloadMacros() {
        os_unfair_lock_lock(&lock)
        macroMap.removeAll(keepingCapacity: true)
        for item in AppSettings.shared.macro.items {
            let key = item.shortcut.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                macroMap[key] = item.replacement
            }
        }
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

        let typedString = String(currentWord)
        let lookupKey = typedString.lowercased()

        guard let rawReplacement = macroMap[lookupKey] else {
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

        return MacroMatchResult(
            handled: true,
            backspaces: backspaces,
            replacement: transformedReplacement + " "
        )
    }
}
