import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

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
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_M: CGKeyCode = 0x2E
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_LeftArrow:  CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
}

@main
struct TestDieuThuyOiLive {
    static func main() {
        print("==================================================================")
        print("  LIVE Test: 'Diễu Thuý ơi' -> Move to 'Diễu' + 'r' -> 'Diểu'     ")
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

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "ru.yandex.desktop.yandex-browser" else {
            print("Error: Yandex Browser not frontmost")
            exit(1)
        }
        print("-> Target: Yandex Browser (PID: \(frontApp.processIdentifier))")

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

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.12, shift: Bool = false) {
            print("  -> Press: '\(char)'")
            if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
                if shift {
                    down.flags = .maskShift
                    up.flags = .maskShift
                } else {
                    down.flags = []
                    up.flags = []
                }
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: delay)
        }

        func inspectAX(step: String) {
            Thread.sleep(forTimeInterval: 0.25)
            let reader = AccessibilityContextReader.shared
            if let elem = reader.getFocusedElement() {
                var valueVal: AnyObject?
                AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valueVal)
                let caret = reader.getSelectedRange(for: elem)?.location ?? -1
                let word = reader.getPrecedingWord() ?? "nil"
                print("  [\(step)] Full: '\(valueVal ?? "" as AnyObject)' | Caret: \(caret) | Word: '\(word)'")
            }
        }

        clearInput()

        // 1. Type: "Diễu Thuý ơi"
        print("\n--- 1. Typing: 'Diễu Thuý ơi' ---")
        // "Diễu" -> Shift+D i e e u x
        typeKey(KeyConstants.kVK_ANSI_D, char: "D", shift: true)
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_X, char: "x")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "Thuý" -> Shift+T h u y s
        typeKey(KeyConstants.kVK_ANSI_T, char: "T", shift: true)
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_Y, char: "y")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "ơi" -> o w i
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_W, char: "w")
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")

        inspectAX(step: "After typing sentence")

        // 2. Move cursor back to 'Diễu'
        // Currently at end of "ơi" (loc 12).
        // To reach end of "Diễu" (loc 4): move back 8 chars (ơi 2 + space 1 + Thuý 4 + space 1 = 8 left arrows)
        print("\n--- 2. Moving cursor back 8 characters to 'Diễu' ---")
        for _ in 1...8 {
            typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08)
        }
        inspectAX(step: "At Diễu")

        // 3. Press 'r' (dấu hỏi) -> Should become 'Diểu'!
        print("\n--- 3. Pressing 'r' (dấu hỏi) on 'Diễu' -> 'Diểu' ---")
        typeKey(KeyConstants.kVK_ANSI_R, char: "r (hỏi)")
        inspectAX(step: "After pressing 'r'")

        print("\n==================================================================")
        print("Done.")
        print("==================================================================")
    }
}
