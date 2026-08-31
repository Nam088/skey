import AppKit
import ApplicationServices

// MARK: - KeyConstants Mapping
enum KeyConstants {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_S: CGKeyCode = 0x01
    static let kVK_ANSI_D: CGKeyCode = 0x02
    static let kVK_ANSI_H: CGKeyCode = 0x04
    static let kVK_ANSI_C: CGKeyCode = 0x08
    static let kVK_ANSI_E: CGKeyCode = 0x0E
    static let kVK_ANSI_R: CGKeyCode = 0x0F
    static let kVK_ANSI_Y: CGKeyCode = 0x10
    static let kVK_ANSI_I: CGKeyCode = 0x22
    static let kVK_ANSI_J: CGKeyCode = 0x26
    static let kVK_ANSI_K: CGKeyCode = 0x28
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_Space:  CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
}

@main
struct YandexTypingTester {
    static func main() {
        print("=====================================================")
        print("  SKey End-to-End Typing Automation Test for Yandex  ")
        print("=====================================================")

        // 1. Focus Yandex Browser & Open Fresh Tab
        print("[1/4] Activating Yandex Browser and opening address bar...")
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
        print("Active Target: Yandex Browser (PID: \(frontApp.processIdentifier))")

        let src = CGEventSource(stateID: .hidSystemState)

        // 2. Clear Existing Content (Cmd+A -> Delete)
        print("[2/4] Clearing existing text (Cmd+A -> Delete)...")
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
        Thread.sleep(forTimeInterval: 0.4)

        // 3. Type "đánh kẻ chạy đi" with configurable delay (default: 300ms)
        print("[3/4] Typing sequence: 'd-d-a-n-h-s Space k-e-r Space c-h-a-y-j Space d-d-i'...")

        func typeKey(_ keyCode: CGKeyCode, char: String, delay: TimeInterval = 0.30) {
            print(" -> Pressing key: '\(char)'")
            if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
                down.flags = []
                up.flags = []
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: delay)
        }

        // Word 1: "đánh"
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_N, char: "n")
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_S, char: "s")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.4)

        // Word 2: "kẻ"
        typeKey(KeyConstants.kVK_ANSI_K, char: "k")
        typeKey(KeyConstants.kVK_ANSI_E, char: "e")
        typeKey(KeyConstants.kVK_ANSI_R, char: "r")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.4)

        // Word 3: "chạy"
        typeKey(KeyConstants.kVK_ANSI_C, char: "c")
        typeKey(KeyConstants.kVK_ANSI_H, char: "h")
        typeKey(KeyConstants.kVK_ANSI_A, char: "a")
        typeKey(KeyConstants.kVK_ANSI_Y, char: "y")
        typeKey(KeyConstants.kVK_ANSI_J, char: "j")
        typeKey(KeyConstants.kVK_Space,  char: "Space", delay: 0.4)

        // Word 4: "đi"
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_D, char: "d")
        typeKey(KeyConstants.kVK_ANSI_I, char: "i")

        Thread.sleep(forTimeInterval: 0.8)
        print("[4/4] Automated typing finished successfully.")
        print("=====================================================")
    }
}
