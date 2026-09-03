import Foundation

public struct InlineCalculationResult {
    public let backspaces: Int
    public let resultText: String
}

public final class InlineCalculator: @unchecked Sendable {
    private var buffer: [Character] = []

    public init() {}

    public func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    public func recordBackspace() {
        if !buffer.isEmpty {
            buffer.removeLast()
        }
    }

    public func process(char: Character) -> InlineCalculationResult? {
        if char.isWhitespace || char.isNewline {
            reset()
            return nil
        }

        if buffer.isEmpty {
            if char == "=" {
                buffer.append(char)
            }
            return nil
        }

        // Inside a potential formula
        if char == "=" {
            // Closing '=' encountered! Check if we have an expression inside
            let charsOnScreen = buffer.count
            let rawString = String(buffer)
            // Strip leading '=' and trim spaces
            let expressionStr = String(rawString.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if let calcResult = evaluate(expressionStr) {
                reset()
                return InlineCalculationResult(backspaces: charsOnScreen, resultText: calcResult)
            } else {
                reset()
                return nil
            }
        }

        // Cap buffer to prevent unbound memory
        if buffer.count >= 128 {
            reset()
            return nil
        }

        buffer.append(char)
        return nil
    }

    public func evaluate(_ rawExpr: String) -> String? {
        let trimmed = rawExpr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var outBuf = [CChar](repeating: 0, count: 128)
        let ret = trimmed.withCString { cStr in
            skey_calc_evaluate(cStr, &outBuf, Int32(outBuf.count))
        }
        guard ret == 1 else { return nil }
        return String(cString: outBuf)
    }
}
