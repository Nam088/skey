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

struct SpeedMode {
    let name: String
    let delaySec: Double
    let description: String
}

@main
struct SpotlightSpeedBenchmarks {
    static func main() {
        print("==================================================================")
        print("Multi-Speed Automated Vietnamese Typing Benchmark for Spotlight")
        print("Target Sentence: 'đánh kẻ chạy đi không ai đánh kẻ chạy lại'")
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

        var axElem = getSpotlightElement()
        if axElem == nil {
            print("Spotlight is not currently open. Attempting Cmd+Space...")
            let script = "tell application \"System Events\" to key code 49 using {command down}"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)

            print("Waiting for Spotlight window to appear (timeout: 15s)...")
            for i in 1...75 {
                Thread.sleep(forTimeInterval: 0.2)
                axElem = getSpotlightElement()
                if axElem != nil {
                    print("-> Spotlight confirmed OPEN and FOCUSED after \(Double(i) * 0.2)s!")
                    break
                }
            }
        }

        guard let targetElement = axElem else {
            print("\n[ERROR] Spotlight is NOT OPEN. Keystrokes were safely cancelled.")
            print("Please press Cmd+Space to open Spotlight and run this test again.")
            exit(1)
        }

        let src = CGEventSource(stateID: .hidSystemState)

        func clearSearchField() {
            if let aDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: true),
               let aUp   = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_A, keyDown: false) {
                aDown.flags = .maskCommand
                aUp.flags = .maskCommand
                aDown.post(tap: .cghidEventTap)
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

            _ = AXUIElementSetAttributeValue(targetElement, kAXValueAttribute as CFString, "" as CFTypeRef)
            var zeroRange = CFRange(location: 0, length: 0)
            if let zeroVal = AXValueCreate(.cfRange, &zeroRange) {
                _ = AXUIElementSetAttributeValue(targetElement, kAXSelectedTextRangeAttribute as CFString, zeroVal)
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        func readSpotlightText() -> String {
            var textVal: AnyObject?
            AXUIElementCopyAttributeValue(targetElement, kAXValueAttribute as CFString, &textVal)
            return (textVal as? String) ?? ""
        }

        let inputSequence = "ddanhs ker chayj ddi khoong ai ddanhs ker chayj laij"
        let expectedSentence = "đánh kẻ chạy đi không ai đánh kẻ chạy lại"

        let modes: [SpeedMode] = [
            SpeedMode(name: "1. Slow (Chậm / Cẩn thận)", delaySec: 0.25, description: "250ms / phím"),
            SpeedMode(name: "2. Normal (Tốc độ thường)", delaySec: 0.15, description: "150ms / phím"),
            SpeedMode(name: "3. Fast (Gõ nhanh)", delaySec: 0.08, description: "80ms / phím"),
            SpeedMode(name: "4. Ultra Fast (Tốc độ siêu nhanh)", delaySec: 0.04, description: "40ms / phím")
        ]

        var results: [(mode: String, passed: Bool, actual: String, timeSec: Double)] = []

        for mode in modes {
            print("\n------------------------------------------------------------------")
            print("Running Mode: \(mode.name) [\(mode.description)]")
            print("------------------------------------------------------------------")

            clearSearchField()
            Thread.sleep(forTimeInterval: 0.3)

            let startTime = CFAbsoluteTimeGetCurrent()

            for char in inputSequence {
                guard let code = keyMap[char] else { continue }
                if let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
                   let up   = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
                    down.flags = []
                    up.flags = []
                    down.post(tap: .cghidEventTap)
                    usleep(12_000)
                    up.post(tap: .cghidEventTap)
                }
                Thread.sleep(forTimeInterval: mode.delaySec)
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            Thread.sleep(forTimeInterval: 0.8)

            let actualText = readSpotlightText()
            let isMatch = (actualText.trimmingCharacters(in: .whitespacesAndNewlines) == expectedSentence)

            results.append((mode: mode.name, passed: isMatch, actual: actualText, timeSec: elapsed))

            print("Elapsed Time: \(String(format: "%.2f", elapsed))s")
            print("Actual Text : '\(actualText)'")
            print("Status      : \(isMatch ? "PASSED" : "FAILED")")
        }

        print("\n==================================================================")
        print("SUMMARY BENCHMARK REPORT")
        print("==================================================================")
        var totalPassed = true
        for r in results {
            let statusStr = r.passed ? "PASS" : "FAIL"
            print("[\(statusStr)] \(r.mode): '\(r.actual)' (\(String(format: "%.2f", r.timeSec))s)")
            if !r.passed { totalPassed = false }
        }
        print("==================================================================")
        print("OVERALL RESULT: \(totalPassed ? "ALL MODES PASSED 100%" : "SOME MODES FAILED")")
        print("==================================================================")
    }
}
