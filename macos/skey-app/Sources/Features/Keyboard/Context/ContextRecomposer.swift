import CoreGraphics
import Foundation

// MARK: - ContextRecomposer

/// Coordinates context-aware word re-composition when editing previously typed words.
/// Uses atomic full-word reconstruction so editing words anywhere in any app (Browsers, Notes, Chat)
/// produces 100% accurate Vietnamese tones with zero buffer corruption.
public final class ContextRecomposer {
    public static let shared = ContextRecomposer()

    private let reader = AccessibilityContextReader.shared
    private let scratchEngine = SKeyEngine()

    private init() {
        scratchEngine.setInputMethod(.telex)
    }

    public static func shouldSkip(bundleID: String?) -> Bool {
        let cat = AppFocusObserver.category(for: bundleID)
        return cat == .developerTool
    }

    private static let telexTriggers: Set<Character> = [
        "a","A","e","E","o","O","u","U","i","I","y","Y","d","D","w","W",
        "s","S","f","F","r","R","x","X","j","J","z","Z"
    ]
    private static let vniTriggers: Set<Character> = [
        "1","2","3","4","5","6","7","8","9","0","d","D","a","A","e","E","o","O","u","U"
    ]

    public static func isTriggerKey(_ char: Character, inputMethodRaw: Int32 = AppSettings.shared.keyboard.inputMethodRawValue) -> Bool {
        inputMethodRaw == InputMethodType.vni.rawValue ? vniTriggers.contains(char) : telexTriggers.contains(char)
    }

    private func isValidCandidate(_ word: String) -> Bool {
        (1...15).contains(word.count) && word.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    public func tryRecompose(charCode: UInt32, engine: SKeyEngine) -> Bool {
        guard let scalar = UnicodeScalar(charCode) else { return false }
        let typedChar = Character(scalar)

        guard Self.isTriggerKey(typedChar),
              !Self.shouldSkip(bundleID: AppFocusObserver.shared.currentBundleID),
              !reader.hasActiveSelection(),
              let word = reader.getPrecedingWord(),
              isValidCandidate(word) else { return false }

        let keys = VietnameseDecomposer.decompose(word: word)
        guard !keys.isEmpty else { return false }

        let im = AppSettings.shared.keyboard.inputMethod
        scratchEngine.setInputMethod(im)
        scratchEngine.reset()

        var reconstructedWord = ""
        for k in keys {
            let r = scratchEngine.filter(character: k)
            if r.handled {
                let bs = r.backspaces
                if bs > 0 && bs <= reconstructedWord.count {
                    reconstructedWord.removeLast(bs)
                }
                reconstructedWord.append(r.text)
            } else if let s = UnicodeScalar(k) {
                reconstructedWord.append(Character(s))
            }
        }

        let finalRes = scratchEngine.filter(character: charCode)
        guard finalRes.handled, !finalRes.text.isEmpty else { return false }

        let bs = finalRes.backspaces
        if bs > 0 && bs <= reconstructedWord.count {
            reconstructedWord.removeLast(bs)
        }
        reconstructedWord.append(finalRes.text)

        guard reconstructedWord != word else { return false }

        // Atomic Replacement of the full word preceding cursor
        let replaceCount = word.count
        if AccessibilityContextReader.isSpotlightActive() {
            _ = reader.replaceTextViaAX(backspaces: replaceCount, text: reconstructedWord)
        } else {
            KeyEventSender.shared.inject(backspaces: replaceCount, text: reconstructedWord)
        }

        // Sync main engine with the newly formed word
        engine.reset()
        let newKeys = VietnameseDecomposer.decompose(word: reconstructedWord)
        for k in newKeys { _ = engine.filter(character: k) }

        skeyLog("Context recomposed: '\(word)' + '\(typedChar)' -> full='\(reconstructedWord)' (bs=\(replaceCount))", category: .keyboard)
        return true
    }
}
