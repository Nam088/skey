import CoreGraphics
import Foundation

// MARK: - ContextRecomposer

/// Coordinates context-aware word re-composition when the user moves the caret
/// back to edit an already-committed word. Uses an isolated scratch engine so that
/// failed context evaluations NEVER corrupt or reset the primary typing buffer.
public final class ContextRecomposer {
    public static let shared = ContextRecomposer()

    private let contextReader = AccessibilityContextReader.shared
    private let scratchEngine = SKeyEngine()

    private init() {
        scratchEngine.setInputMethod(.telex)
    }

    /// Set of bundle IDs where context re-composition should be skipped.
    private static let skipRecomposeApps: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.sublimetext.4",
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.webstorm",
        "com.jetbrains.goland",
        "com.jetbrains.rider",
        "com.jetbrains.clion",
        "com.mitchellh.ghostty",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty",
        "org.alacritty",
    ]

    /// Set of ASCII characters that can trigger a Vietnamese transformation or accent modification.
    private static let triggerChars: Set<Character> = [
        "a", "A", "e", "E", "o", "O", "u", "U", "i", "I", "y", "Y",
        "d", "D", "w", "W", "s", "S", "f", "F", "r", "R", "x", "X", "j", "J",
        "1", "2", "3", "4", "5", "6", "7", "8", "9"
    ]

    /// Attempts to reconstruct the composing buffer from preceding word and evaluate new keystroke.
    /// Returns true if successfully re-composed and injected.
    public func tryRecompose(
        charCode: UInt32,
        engine: SKeyEngine
    ) -> Bool {
        guard let scalar = UnicodeScalar(charCode) else { return false }
        let typedChar = Character(scalar)

        guard Self.triggerChars.contains(typedChar) else {
            return false
        }

        // Skip AX IPC entirely for developer/terminal apps:
        if let bundleID = AppFocusObserver.shared.currentBundleID,
           Self.skipRecomposeApps.contains(bundleID) {
            return false
        }

        // Read preceding word before caret
        guard let word = contextReader.getPrecedingWord(), !word.isEmpty else {
            return false
        }

        // Decompose preceding word into raw keystroke sequence
        let decomposedKeystrokes = VietnameseDecomposer.decompose(word: word)
        guard !decomposedKeystrokes.isEmpty else { return false }

        // Use isolated scratch engine to evaluate without corrupting primary engine
        scratchEngine.reset()
        for key in decomposedKeystrokes {
            _ = scratchEngine.filter(character: key)
        }

        // Evaluate new character on reconstructed buffer
        let res = scratchEngine.filter(character: charCode)
        if res.handled && !res.text.isEmpty {
            // Context recomposition succeeded: update primary engine with new state
            engine.reset()
            for key in decomposedKeystrokes {
                _ = engine.filter(character: key)
            }
            _ = engine.filter(character: charCode)

            let backspaces = res.backspaces > 0 ? res.backspaces : word.count
            KeyEventSender.shared.inject(backspaces: backspaces, text: res.text)
            skeyLog("Context recomposed: '\(word)' + '\(typedChar)' -> bs=\(backspaces) '\(res.text)'", category: .keyboard)
            return true
        }

        // If not handled, leave primary engine completely untouched!
        return false
    }
}
