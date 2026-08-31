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
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_M: CGKeyCode = 0x2E
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_LeftArrow:  CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
}

@main
struct TestDuongEmDi {
    static func main() {
        print("==================================================================")
        print("  LIVE Multi-Word Back-and-Forth Cursor Tone Test on Yandex       ")
        print("  Phrase: 'đường em đi là đường bên phải'                         ")
        print("==================================================================")

        // 1. Activate Yandex Browser and focus Address Bar (Cmd+L)
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

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.12) {
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

        // 1. Type: "đường em đi là đường bên phải"
        print("\n--- 1. Typing Initial Sentence ---")
        // "đường" -> d d u o w n g f
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_W, char: "w")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_G, char: "g")
        typeKey(KeyConstants.kVK_ANSI_F, char: "f")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "em" -> e m
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_M, char: "m")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "đi" -> d d i
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "là" -> l a f
        typeKey(KeyConstants.kVK_ANSI_L, char: "l")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_F, char: "f")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "đường" -> d d u o w n g f
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_W, char: "w")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_G, char: "g")
        typeKey(KeyConstants.kVK_ANSI_F, char: "f")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "bên" -> b e e n
        typeKey(KeyConstants.kVK_ANSI_B, char: "b")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_Space,  char: "Space")

        // "phải" -> p h a i r
        typeKey(KeyConstants.kVK_ANSI_P, char: "p")
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")
        typeKey(KeyConstants.kVK_ANSI_R, char: "r")

        inspectAX(step: "Initial")

        // 2. Modify 'phải' -> press 's' -> 'phái'
        print("\n--- 2. Modify 'phải' -> 's' -> 'phái' ---")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        inspectAX(step: "phải -> phái")

        // 3. Move cursor back to 'bên' (← 5 chars: 'phái' 4 + space 1)
        print("\n--- 3. Move back 5 chars to 'bên' -> 's' -> 'bến' ---")
        for _ in 1...5 { typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        inspectAX(step: "bên -> bến")

        // 4. Move cursor back to 2nd 'đường' (← 4 chars: 'bến' 3 + space 1)
        print("\n--- 4. Move back 4 chars to 2nd 'đường' -> 'x' -> 'đưỡng' ---")
        for _ in 1...4 { typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_X, char: "x (ngã)")
        inspectAX(step: "đường -> đưỡng")

        // 5. Move cursor back to 'là' (← 6 chars: 'đưỡng' 5 + space 1)
        print("\n--- 5. Move back 6 chars to 'là' -> 's' -> 'lá' ---")
        for _ in 1...6 { typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        inspectAX(step: "là -> lá")

        // 6. Move cursor back to 'đi' (← 3 chars: 'lá' 2 + space 1)
        print("\n--- 6. Move back 3 chars to 'đi' -> 's' -> 'đí' ---")
        for _ in 1...3 { typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        inspectAX(step: "đi -> đí")

        // 7. Move cursor back to 1st 'đường' (← 6 chars: 'đí' 2 + space 1 + 'em' 2 + space 1)
        print("\n--- 7. Move back 6 chars to 1st 'đường' -> 'j' -> 'đượng' ---")
        for _ in 1...6 { typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_J, char: "j (nặng)")
        inspectAX(step: "đường -> đượng")

        // 8. Now move FORWARD to 'bến' and change back to 'bền' (press 'f')
        print("\n--- 8. Move FORWARD to 'bến' -> 'f' -> 'bền' ---")
        // Currently at loc=5 (end of 1st 'đượng').
        // To reach end of 'bến': + space 1 + 'em' 2 + space 1 + 'đí' 2 + space 1 + 'lá' 2 + space 1 + 'đưỡng' 5 + space 1 + 'bến' 3 = 19 right arrows
        for _ in 1...19 { typeKey(KeyConstants.kVK_RightArrow, char: "→", delay: 0.08) }
        typeKey(KeyConstants.kVK_ANSI_F, char: "f (huyền)")
        inspectAX(step: "bến -> bền")

        print("\n==================================================================")
        print("Test Complete.")
        print("==================================================================")
    }
}
