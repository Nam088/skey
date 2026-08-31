import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Key Constants
enum KeyConstants {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_S: CGKeyCode = 0x01
    static let kVK_ANSI_D: CGKeyCode = 0x02
    static let kVK_ANSI_H: CGKeyCode = 0x04
    static let kVK_ANSI_G: CGKeyCode = 0x05
    static let kVK_ANSI_X: CGKeyCode = 0x07
    static let kVK_ANSI_C: CGKeyCode = 0x08
    static let kVK_ANSI_O: CGKeyCode = 0x1F
    static let kVK_ANSI_I: CGKeyCode = 0x22
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_ANSI_L: CGKeyCode = 0x25
}

@main
struct YandexLiveTest {
    static func main() {
        print("=====================================================")
        print("  LIVE End-to-End Test: SKey on Yandex Browser       ")
        print("=====================================================")

        // 1. Activate Yandex Browser
        print("[1/5] Activating Yandex Browser...")
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
        print("[2/5] Clearing address bar / active input...")
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

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.15) {
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

        // 3. Test pressing 'x' standalone first
        print("\n[3/5] TEST A: Pressing standalone 'x' key (Previously bugged into 'úy' / 'ũy')...")
        typeKey(KeyConstants.kVK_ANSI_X, char: "x", delay: 0.4)

        // Clear again
        if let delDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: true),
           let delUp = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: false) {
            delDown.flags = []
            delUp.flags = []
            delDown.post(tap: .cghidEventTap)
            delUp.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: 0.2)

        // 4. Test typing "xong xin chao"
        print("\n[4/5] TEST B: Typing sequence: 'x-o-n-g Space x-i-n Space c-h-a-o-s' ('xong xin chào')...")
        // "xong"
        typeKey(KeyConstants.kVK_ANSI_X, char: "x")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_G, char: "g")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.25)

        // "xin"
        typeKey(KeyConstants.kVK_ANSI_X, char: "x")
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.25)

        // "chào"
        typeKey(KeyConstants.kVK_ANSI_C, char: "c")
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_O, char: "o")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s (huyền -> f, sắc -> s)")

        Thread.sleep(forTimeInterval: 0.5)
        print("\n[5/5] Live typing finished successfully.")
        print("=====================================================")
    }
}
