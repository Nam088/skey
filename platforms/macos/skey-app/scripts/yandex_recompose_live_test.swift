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
    static let kVK_ANSI_1: CGKeyCode = 0x12
    static let kVK_ANSI_2: CGKeyCode = 0x13
    static let kVK_ANSI_3: CGKeyCode = 0x14
    static let kVK_ANSI_4: CGKeyCode = 0x15
    static let kVK_ANSI_6: CGKeyCode = 0x16
    static let kVK_ANSI_5: CGKeyCode = 0x17
    static let kVK_ANSI_Equal: CGKeyCode = 0x18
    static let kVK_ANSI_9: CGKeyCode = 0x19
    static let kVK_ANSI_7: CGKeyCode = 0x1A
    static let kVK_ANSI_Minus: CGKeyCode = 0x1B
    static let kVK_ANSI_8: CGKeyCode = 0x1C
    static let kVK_ANSI_0: CGKeyCode = 0x1D
    static let kVK_ANSI_RightBracket: CGKeyCode = 0x1E
    static let kVK_ANSI_O: CGKeyCode = 0x1F
    static let kVK_ANSI_U: CGKeyCode = 0x20
    static let kVK_ANSI_LeftBracket: CGKeyCode = 0x21
    static let kVK_ANSI_I: CGKeyCode = 0x22
    static let kVK_ANSI_P: CGKeyCode = 0x23
    static let kVK_ANSI_L: CGKeyCode = 0x25
    static let kVK_ANSI_J: CGKeyCode = 0x26
    static let kVK_ANSI_K: CGKeyCode = 0x28
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_M: CGKeyCode = 0x2E
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_LeftArrow:  CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
    static let kVK_DownArrow:  CGKeyCode = 0x7D
    static let kVK_UpArrow:    CGKeyCode = 0x7E
}

@main
struct YandexRecomposeLiveTest {
    static func main() {
        print("==================================================================")
        print("  LIVE Cursor Movement & Tone Change Test on Yandex Browser       ")
        print("==================================================================")

        // 1. Activate Yandex Browser
        print("[1/6] Activating Yandex Browser...")
        let script = """
        tell application "Yandex"
            activate
        end tell
        delay 0.5
        tell application "System Events"
            tell process "Yandex"
                keystroke "t" using command down
            end tell
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        Thread.sleep(forTimeInterval: 0.8)

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "ru.yandex.desktop.yandex-browser" else {
            print("Error: Yandex Browser is not frontmost. Found: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            exit(1)
        }
        print("-> Active Target: Yandex Browser (PID: \(frontApp.processIdentifier))")

        let src = CGEventSource(stateID: .hidSystemState)

        // 2. Clear Existing Content (Cmd+A -> Delete)
        print("[2/6] Clearing address bar / active input...")
        if let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }
        if let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: false) {
            cmdUp.flags = .maskCommand
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
        Thread.sleep(forTimeInterval: 0.3)

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.12) {
            print("  -> Pressing key: '\(char)'")
            if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
                down.flags = []
                up.flags = []
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: delay)
        }

        // 3. Type "ấn tượng chuyên sâu"
        print("\n[3/6] Typing: 'ấn tượng chuyên sâu'...")
        // "ấn" -> a s n s or a a s n
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.2)

        // "tượng" -> t u o n g j w or t u o w n g j
        typeKey(KeyConstants.kVK_ANSI_T, char: "t")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_G, char: "g")
        typeKey(KeyConstants.kVK_ANSI_W, char: "w")
        typeKey(KeyConstants.kVK_ANSI_J, char: "j")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.2)

        // "chuyên" -> c h u y e e n
        typeKey(KeyConstants.kVK_ANSI_C, char: "c")
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_Y, char: "y")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.2)

        // "sâu" -> s a a u
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")

        Thread.sleep(forTimeInterval: 0.5)

        // 4. Move cursor back to "chuyên"
        // Cursor is currently at end of "sâu".
        // "sâu" is 3 chars. Space is 1 char. Total 4 left arrows to reach end of "chuyên".
        print("\n[4/6] Moving cursor back 4 characters (to end of 'chuyên')...")
        for _ in 1...4 {
            typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.1)
        }
        Thread.sleep(forTimeInterval: 0.3)

        // Now test changing accent on "chuyên" by pressing 's' -> should become "chuyến"!
        print("\n[5/6] Pressing 's' to change tone on 'chuyên' -> 'chuyến'...")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        Thread.sleep(forTimeInterval: 0.5)

        // 5. Move cursor back to "tượng"
        // "chuyến" is 6 chars. Space is 1 char. Total 7 left arrows to reach end of "tượng".
        print("\n[6/6] Moving cursor back 7 characters (to end of 'tượng')...")
        for _ in 1...7 {
            typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.1)
        }
        Thread.sleep(forTimeInterval: 0.3)

        // Press 's' to change tone on "tượng" -> "tướng"
        print("  -> Pressing 's' to change tone on 'tượng' -> 'tướng'...")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (sắc)")
        Thread.sleep(forTimeInterval: 0.5)

        print("\n==================================================================")
        print("Test sequence completed.")
        print("==================================================================")
    }
}
