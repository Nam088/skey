import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@main
struct TestYandexCursor {
    static func main() {
        print("--- Testing Yandex Cursor and AX Preceding Word Extraction ---")

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("No front app")
            return
        }
        print("Front App: \(frontApp.bundleIdentifier ?? "unknown") (PID: \(frontApp.processIdentifier))")

        let reader = AccessibilityContextReader.shared
        if let elem = reader.getFocusedElement() {
            var roleVal: AnyObject?
            AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleVal)
            print("Focused Element Role: \(roleVal ?? "nil" as AnyObject)")

            var titleVal: AnyObject?
            AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleVal)
            print("Focused Element Title: \(titleVal ?? "nil" as AnyObject)")

            var valueVal: AnyObject?
            AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valueVal)
            print("Full Value String: '\(valueVal ?? "nil" as AnyObject)'")

            if let range = reader.getSelectedRange(for: elem) {
                print("Selected Range: loc=\(range.location), len=\(range.length)")
            } else {
                print("Selected Range: nil")
            }

            if let word = reader.getPrecedingWord() {
                print("Extracted Preceding Word: '\(word)'")
                let decomp = VietnameseDecomposer.decompose(word: word)
                print("Decomposed Keys: \(decomp.map { String(UnicodeScalar($0) ?? " ") })")
            } else {
                print("Extracted Preceding Word: nil")
            }
        } else {
            print("Focused Element: nil")
        }
    }
}
