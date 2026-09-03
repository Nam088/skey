import Foundation

/// Fast-path detector for programmer tokens (CamelCase, snake_case, CLI flags, prefixes)
/// to prevent accidental Vietnamese diacritics when coding.
public final class SmartCoderModeDetector: @unchecked Sendable {
    private var isCodeToken: Bool = false
    private var hasLowercaseLetter: Bool = false
    private var currentWordLen: Int = 0
    private var codeTokenTriggerLen: Int = 0

    public init() {}

    public func reset() {
        isCodeToken = false
        hasLowercaseLetter = false
        currentWordLen = 0
        codeTokenTriggerLen = 0
    }

    /// Evaluates whether the incoming character should trigger Coder Mode bypass.
    /// Returns true if this character (and the current word) should bypass the Vietnamese engine.
    public func process(char: Character) -> Bool {
        // Word boundary: reset state
        if char.isWhitespace || char.isNewline {
            reset()
            return false
        }

        // If this token was already identified as code, continue bypassing
        if isCodeToken {
            currentWordLen += 1
            return true
        }

        // Check 1: Code prefixes at the start of a word
        if currentWordLen == 0 {
            if char == "_" || char == "$" || char == "@" || char == "/" || char == "-" || char == "." {
                isCodeToken = true
                codeTokenTriggerLen = 1
                currentWordLen = 1
                return true
            }
        }

        // Check 2: Snake_case or kebab-case delimiter inside a word
        if currentWordLen > 0 && (char == "_" || char == "-") {
            isCodeToken = true
            codeTokenTriggerLen = currentWordLen + 1
            currentWordLen += 1
            return true
        }

        // Check 3: CamelCase detection
        // If the word has already seen one or more lowercase letters,
        // and now an uppercase ASCII letter arrives (e.g. "myV", "isA"):
        if hasLowercaseLetter && char.isASCII && char.isUppercase {
            isCodeToken = true
            codeTokenTriggerLen = currentWordLen + 1
            currentWordLen += 1
            return true
        }

        if char.isASCII && char.isLowercase {
            hasLowercaseLetter = true
        }

        currentWordLen += 1
        return false
    }

    public func recordBackspace() {
        if currentWordLen > 0 {
            currentWordLen -= 1
            if currentWordLen < codeTokenTriggerLen {
                isCodeToken = false
                codeTokenTriggerLen = 0
            }
            if currentWordLen == 0 {
                reset()
            }
        }
    }
}
