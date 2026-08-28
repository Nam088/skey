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
    static let kVK_ANSI_J: CGKeyCode = 0x26
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_LeftArrow:  CGKeyCode = 0x7B
}

@main
struct TestTuongXOnYandex {
    static func main() {
        print("==================================================================")
        print("  LIVE Test: Typing 'tượng' + 'x' -> 'tưỡng' on Yandex Browser   ")
        print("==================================================================")

        // 1. Activate Yandex Browser
        let script = """
        tell application "Yandex"
            activate
        end tell
        delay 0.3
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

        // Test 1: Type 'tượng' then Space, then type something else, then move cursor back to 'tượng' and press 'x'
        print("\n--- Test: 'ấn tượng chuyên sâu' -> Move cursor to 'tượng' -> Press 'x' -> 'tưỡng' ---")
        clearInput()

        // "ấn"
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.2)

        // "tượng"
        typeKey(KeyConstants.kVK_ANSI_T, char: "t")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_W, char: "w")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_G, char: "g")
        typeKey(KeyConstants.kVK_ANSI_J, char: "j")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.2)

        // "sâu"
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_U, char: "u")
        Thread.sleep(forTimeInterval: 0.4)

        // Cursor is at end of "sâu" (length: 3 + space: 1 = 4 left arrows)
        print("  -> Moving cursor back 4 chars to end of 'tượng'...")
        for _ in 1...4 {
            typeKey(KeyConstants.kVK_LeftArrow, char: "←", delay: 0.1)
        }
        Thread.sleep(forTimeInterval: 0.3)

        // Press 'x' to change tone on "tượng" -> should become "tưỡng"!
        print("  -> Pressing 'x' on 'tượng'...")
        typeKey(KeyConstants.kVK_ANSI_X, char: "x (ngã)")
        Thread.sleep(forTimeInterval: 0.6)

        print("\n==================================================================")
        print("Done test.")
        print("==================================================================")
    }
}
