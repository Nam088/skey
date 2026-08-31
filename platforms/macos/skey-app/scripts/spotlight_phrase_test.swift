import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - KeyCode Mapping
enum KeyConstants {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_S: CGKeyCode = 0x01
    static let kVK_ANSI_D: CGKeyCode = 0x02
    static let kVK_ANSI_F: CGKeyCode = 0x03
    static let kVK_ANSI_H: CGKeyCode = 0x04
    static let kVK_ANSI_G: CGKeyCode = 0x05
    static let kVK_ANSI_Z: CGKeyCode = 0x06
    static let kVK_ANSI_X: CGKeyCode = 0x07
    static let kVK_ANSI_C: CGKeyCode = 0x08
    static let kVK_ANSI_V: CGKeyCode = 0x09
    static let kVK_ANSI_B: CGKeyCode = 0x0B
    static let kVK_ANSI_Q: CGKeyCode = 0x0C
    static let kVK_ANSI_W: CGKeyCode = 0x0D
    static let kVK_ANSI_E: CGKeyCode = 0x0E
    static let kVK_ANSI_R: CGKeyCode = 0x0F
    static let kVK_ANSI_Y: CGKeyCode = 0x10
    static let kVK_ANSI_T: CGKeyCode = 0x11
    static let kVK_ANSI_O: CGKeyCode = 0x1F
    static let kVK_ANSI_U: CGKeyCode = 0x20
    static let kVK_ANSI_I: CGKeyCode = 0x22
    static let kVK_ANSI_P: CGKeyCode = 0x23
    static let kVK_ANSI_L: CGKeyCode = 0x25
    static let kVK_ANSI_J: CGKeyCode = 0x26
    static let kVK_ANSI_K: CGKeyCode = 0x28
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_M: CGKeyCode = 0x2E
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
}

let keyMap: [Character: CGKeyCode] = [
    "a": KeyConstants.kVK_ANSI_A,
    "s": KeyConstants.kVK_ANSI_S,
    "d": KeyConstants.kVK_ANSI_D,
    "f": KeyConstants.kVK_ANSI_F,
    "h": KeyConstants.kVK_ANSI_H,
    "g": KeyConstants.kVK_ANSI_G,
    "z": KeyConstants.kVK_ANSI_Z,
    "x": KeyConstants.kVK_ANSI_X,
    "c": KeyConstants.kVK_ANSI_C,
    "v": KeyConstants.kVK_ANSI_V,
    "b": KeyConstants.kVK_ANSI_B,
    "q": KeyConstants.kVK_ANSI_Q,
    "w": KeyConstants.kVK_ANSI_W,
    "e": KeyConstants.kVK_ANSI_E,
    "r": KeyConstants.kVK_ANSI_R,
    "y": KeyConstants.kVK_ANSI_Y,
    "t": KeyConstants.kVK_ANSI_T,
    "o": KeyConstants.kVK_ANSI_O,
    "u": KeyConstants.kVK_ANSI_U,
    "i": KeyConstants.kVK_ANSI_I,
    "p": KeyConstants.kVK_ANSI_P,
    "l": KeyConstants.kVK_ANSI_L,
    "j": KeyConstants.kVK_ANSI_J,
    "k": KeyConstants.kVK_ANSI_K,
    "n": KeyConstants.kVK_ANSI_N,
    "m": KeyConstants.kVK_ANSI_M,
    " ": KeyConstants.kVK_Space
]

@main
struct SpotlightPhraseTest {
    static func main() {
        print("==================================================================")
        print("Spotlight Phrase & Sentence Progression Test")
        print("==================================================================")

        func getSpotlightElement() -> AXUIElement? {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight")
            guard let spot = apps.first else { return nil }
            let spotElem = AXUIElementCreateApplication(spot.processIdentifier)
            var focusedVal: AnyObject?
            if AXUIElementCopyAttributeValue(spotElem, kAXFocusedUIElementAttribute as CFString, &focusedVal) == .success,
               let elem = focusedVal,
               CFGetTypeID(elem) == AXUIElementGetTypeID() {
                // swiftlint:disable:next force_cast
                return (elem as! AXUIElement)
            }
            return nil
        }

        guard let targetElement = getSpotlightElement() else {
            print("[ERROR] Spotlight is NOT OPEN.")
            exit(1)
        }

        let src = CGEventSource(stateID: .hidSystemState)

        func clearSearchField() {
            if let aDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: true) {
                aDown.flags = .maskCommand
                aDown.post(tap: .cghidEventTap)
            }
            if let aUp = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: false) {
                aUp.flags = .maskCommand
                aUp.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.1)

            if let delDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: true),
               let delUp   = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: false) {
                delDown.flags = []
                delUp.flags = []
                delDown.post(tap: .cghidEventTap)
                delUp.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        func readSpotlightText() -> String {
            var textVal: AnyObject?
            AXUIElementCopyAttributeValue(targetElement, kAXValueAttribute as CFString, &textVal)
            return (textVal as? String) ?? ""
        }

        func typePhrase(_ phrase: String, delayPerKey: Double = 0.10) {
            for char in phrase {
                guard let code = keyMap[char] else { continue }
                if let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
                   let up   = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
                    down.flags = []
                    up.flags = []
                    down.post(tap: .cghidEventTap)
                    usleep(12_000)
                    up.post(tap: .cghidEventTap)
                }
                Thread.sleep(forTimeInterval: delayPerKey)
            }
        }

        let testPhrases: [(input: String, expected: String)] = [
            ("ddanhs ker", "đánh kẻ"),
            ("chayj ddi", "chạy đi"),
            ("khoong ai", "không ai"),
            ("ddanhs ker chayj ddi", "đánh kẻ chạy đi"),
            ("khoong ai ddanhs ker chayj laij", "không ai đánh kẻ chạy lại"),
            ("ddanhs ker chayj ddi khoong ai ddanhs ker chayj laij", "đánh kẻ chạy đi không ai đánh kẻ chạy lại")
        ]

        var allPassed = true

        for (index, tp) in testPhrases.enumerated() {
            clearSearchField()
            Thread.sleep(forTimeInterval: 0.2)

            print("\n------------------------------------------------------------------")
            print("Phrase [\(index + 1)/\(testPhrases.count)]: '\(tp.input)' -> '\(tp.expected)'")
            print("------------------------------------------------------------------")

            typePhrase(tp.input, delayPerKey: 0.10)
            Thread.sleep(forTimeInterval: 0.4)

            let actual = readSpotlightText().trimmingCharacters(in: .whitespacesAndNewlines)
            let passed = (actual == tp.expected)

            print("Actual : '\(actual)'")
            print("Status : \(passed ? "PASS" : "FAIL")")

            if !passed {
                allPassed = false
            }
        }

        print("\n==================================================================")
        print("PHRASE TEST SUMMARY")
        print("==================================================================")
        print("RESULT: \(allPassed ? "ALL PHRASES PASSED (100%)" : "SOME PHRASES FAILED")")
        print("==================================================================")
    }
}
