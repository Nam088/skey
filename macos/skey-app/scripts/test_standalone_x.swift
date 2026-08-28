import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum KeyConstants {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_X: CGKeyCode = 0x07
    static let kVK_ANSI_O: CGKeyCode = 0x1F
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_G: CGKeyCode = 0x05
    static let kVK_ANSI_L: CGKeyCode = 0x25
    static let kVK_Delete: CGKeyCode = 0x33
}

@main
struct TestStandaloneXOnYandex {
    static func main() {
        print("==================================================================")
        print("  LIVE Test: Standalone 'x' on Yandex (Must NOT become 'Thuỹ')    ")
        print("==================================================================")

        let script = """
        tell application "Yandex"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            tell process "Yandex"
                keystroke "l" using command down
            end tell
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        Thread.sleep(forTimeInterval: 0.6)

        let src = CGEventSource(stateID: .hidSystemState)

        func clearInput() {
            if let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: true),
               let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: false) {
                cmdDown.flags = .maskCommand
                cmdUp.flags = .maskCommand
                cmdDown.post(tap: .cghidEventTap)
                cmdUp.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.15)
            if let delDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: true),
               let delUp = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: false) {
                delDown.flags = []
                delUp.flags = []
                delDown.post(tap: .cghidEventTap)
                delUp.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.25)
        }

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.15) {
            print("  -> Press: '\(char)'")
            if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
                down.flags = []
                up.flags = []
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: delay)
        }

        clearInput()

        print("\n--- Test: Typing single 'x' on fresh focused field ---")
        typeKey(KeyConstants.kVK_ANSI_X, char: "x")
        Thread.sleep(forTimeInterval: 0.4)

        let reader = AccessibilityContextReader.shared
        if let elem = reader.getFocusedElement() {
            var val: AnyObject?
            AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &val)
            print("  -> Value on Screen: '\(val ?? "" as AnyObject)'")
            if (val as? String) == "x" {
                print("  => [PASS] Got exact single 'x' (no ghost 'Thuỹ'!)")
            } else {
                print("  => [FAIL] Unexpected value: '\(val ?? "" as AnyObject)'")
            }
        }

        print("\n==================================================================")
        print("Done.")
        print("==================================================================")
    }
}
