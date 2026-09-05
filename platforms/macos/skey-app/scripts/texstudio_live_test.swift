import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Key Constants
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
    static let kVK_ANSI_J: CGKeyCode = 0x26
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
    "j": KeyConstants.kVK_ANSI_J,
    "n": KeyConstants.kVK_ANSI_N,
    "m": KeyConstants.kVK_ANSI_M,
    " ": KeyConstants.kVK_Space
]

@main
struct TeXstudioLiveTest {
    static func main() {
        print("=====================================================")
        print("  LIVE End-to-End Test: SKey on TeXstudio            ")
        print("=====================================================")

        // 1. Activate TeXstudio
        print("[1/5] Activating TeXstudio...")
        guard let texApp = NSRunningApplication.runningApplications(withBundleIdentifier: "texstudio").first else {
            print("Error: TeXstudio is not running. Launch it first.")
            exit(1)
        }

        texApp.activate(options: .activateIgnoringOtherApps)
        Thread.sleep(forTimeInterval: 0.8)

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "texstudio" else {
            print("Error: TeXstudio is not frontmost. Found: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            exit(1)
        }
        print("-> Active Target: TeXstudio (PID: \(frontApp.processIdentifier))")

        let src = CGEventSource(stateID: .hidSystemState)

        func pressKey(_ code: CGKeyCode, flags: CGEventFlags = [], delay: TimeInterval = 0.05) {
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) else { return }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            usleep(12_000)
            up.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: delay)
        }

        func typeSequence(_ seq: String, delay: TimeInterval = 0.15) {
            for char in seq {
                if let code = keyMap[char] {
                    pressKey(code, delay: delay)
                }
            }
        }

        // 2. Open a fresh tab / document with Cmd+N
        print("[2/5] Creating fresh document (Cmd+N)...")
        pressKey(KeyConstants.kVK_ANSI_N, flags: .maskCommand, delay: 0.5)

        // 3. Select All and Clear just in case
        print("[3/5] Clearing editor buffer (Cmd+A -> Delete)...")
        pressKey(KeyConstants.kVK_ANSI_A, flags: .maskCommand, delay: 0.15)
        pressKey(KeyConstants.kVK_Delete, delay: 0.3)

        // 4. Type test sequence: "ddans tieengs vieetj"
        print("[4/5] Typing test phrase: 'ddans tieengs vieetj' (expected: 'đán tiếng việt')...")
        typeSequence("ddans tieengs vieetj ", delay: 0.15)
        Thread.sleep(forTimeInterval: 0.6)

        // 5. Read back text via Cmd+A -> Cmd+C -> Clipboard
        print("[5/5] Reading back text via Clipboard (Cmd+A -> Cmd+C)...")
        NSPasteboard.general.clearContents()
        pressKey(KeyConstants.kVK_ANSI_A, flags: .maskCommand, delay: 0.2)
        pressKey(KeyConstants.kVK_ANSI_C, flags: .maskCommand, delay: 0.3)

        let result = NSPasteboard.general.string(forType: .string) ?? ""
        print("\n=====================================================")
        print("  RESULT FROM TEXSTUDIO: [\(result)]")
        print("=====================================================")
        if result.contains("đán") {
            print("-> Test 'ddans' -> 'đán': PASSED")
        } else {
            print("-> Test 'ddans' -> 'đán': FAILED (Actual: '\(result)')")
        }
    }
}
