import CoreGraphics
import Foundation

// MARK: - ContextRecomposer

/// Coordinates context-aware word re-composition when editing previously typed words.
/// Uses an isolated scratch engine so failed recompositions never corrupt the main buffer.
public final class ContextRecomposer {
    public static let shared = ContextRecomposer()

    private let reader = AccessibilityContextReader.shared
    private let scratchEngine = SKeyEngine()

    private init() {
        scratchEngine.setInputMethod(.telex)
    }

    public static func shouldSkip(bundleID: String?) -> Bool {
        let cat = AppFocusObserver.category(for: bundleID)
        return cat == .developerTool || cat == .webBrowser || cat == .electronOrChat
    }

    private static let telexTriggers: Set<Character> = ["a","A","e","E","o","O","u","U","i","I","y","Y","d","D","w","W","s","S","f","F","r","R","x","X","j","J","z","Z"]
    private static let vniTriggers: Set<Character> = ["1","2","3","4","5","6","7","8","9","0","d","D","a","A","e","E","o","O","u","U"]

    public static func isTriggerKey(_ char: Character, inputMethodRaw: Int32 = AppSettings.shared.keyboard.inputMethodRawValue) -> Bool {
        inputMethodRaw == InputMethodType.vni.rawValue ? vniTriggers.contains(char) : telexTriggers.contains(char)
    }

    private func isValidCandidate(_ word: String) -> Bool {
        (1...8).contains(word.count) && word.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    public func tryRecompose(charCode: UInt32, engine: SKeyEngine) -> Bool {
        guard let scalar = UnicodeScalar(charCode) else { return false }
        let typedChar = Character(scalar)

        guard Self.isTriggerKey(typedChar),
              !Self.shouldSkip(bundleID: AppFocusObserver.shared.currentBundleID),
              let word = reader.getPrecedingWord(),
              isValidCandidate(word) else { return false }

        let keys = VietnameseDecomposer.decompose(word: word)
        guard !keys.isEmpty else { return false }

        let im = AppSettings.shared.keyboard.inputMethod
        scratchEngine.setInputMethod(im)
        scratchEngine.reset()
        for k in keys { _ = scratchEngine.filter(character: k) }

        let res = scratchEngine.filter(character: charCode)
        guard res.handled, !res.text.isEmpty else { return false }

        engine.reset()
        for k in keys { _ = engine.filter(character: k) }
        _ = engine.filter(character: charCode)

        let bs = res.backspaces > 0 ? res.backspaces : word.count
        KeyEventSender.shared.inject(backspaces: bs, text: res.text)
        skeyLog("Context recomposed: '\(word)' + '\(typedChar)' -> bs=\(bs) '\(res.text)'", category: .keyboard)
        return true
    }
}
