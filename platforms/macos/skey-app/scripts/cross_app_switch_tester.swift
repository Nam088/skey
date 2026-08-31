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
    static let kVK_Escape: CGKeyCode = 0x35
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

@main
struct CrossAppSwitchTester {
    static func main() {
        print("==================================================================")
        print("Cross-App Switch & Buffer Isolation Test")
        print("Testing: Spotlight typing -> Close Spotlight -> Type in Normal App")
        print("==================================================================")

        let src = CGEventSource(stateID: .hidSystemState)

        func isSpotlightVisible() -> Bool {
            guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                return false
            }
            return windowList.contains { ($0[kCGWindowOwnerName as String] as? String ?? "") == "Spotlight" && ($0[kCGWindowLayer as String] as? Int ?? 0) > 0 }
        }

        func getSpotlightElement() -> AXUIElement? {
            guard isSpotlightVisible() else { return nil }
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight")
            guard let spot = apps.first else { return nil }
            let spotElem = AXUIElementCreateApplication(spot.processIdentifier)
            var focusedVal: AnyObject?
            if AXUIElementCopyAttributeValue(spotElem, kAXFocusedUIElementAttribute as CFString, &focusedVal) == .success,
               let elem = focusedVal, CFGetTypeID(elem) == AXUIElementGetTypeID() {
                return (elem as! AXUIElement)
            }
            return nil
        }

        func typeSequence(_ seq: String, delay: Double = 0.08) {
            for char in seq {
                guard let code = keyMap[char] else { continue }
                let d = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!
                let u = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!
                d.flags = []; u.flags = []
                d.post(tap: .cghidEventTap)
                usleep(12_000)
                u.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: delay)
            }
        }

        // Step 1: Open and Activate Spotlight
        print("\n[Step 1] Opening and Activating Spotlight...")
        let spotApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight")
        if let spot = spotApps.first {
            spot.activate(options: .activateIgnoringOtherApps)
        }
        if !isSpotlightVisible() {
            let script = "tell application \"System Events\" to key code 49 using {command down}"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            Thread.sleep(forTimeInterval: 0.5)
        }

        var targetElem: AXUIElement?
        for _ in 1...20 {
            if let elem = getSpotlightElement() {
                targetElem = elem
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        guard let spotElem = targetElem else {
            print("[ERROR] Spotlight failed to open or focus.")
            exit(1)
        }

        // Clear Spotlight
        _ = AXUIElementSetAttributeValue(spotElem, kAXValueAttribute as CFString, "" as CFTypeRef)
        var zero = CFRange(location: 0, length: 0)
        let zVal = AXValueCreate(.cfRange, &zero)!
        _ = AXUIElementSetAttributeValue(spotElem, kAXSelectedTextRangeAttribute as CFString, zVal)
        Thread.sleep(forTimeInterval: 0.2)

        // Type in Spotlight
        print("[Step 2] Typing in Spotlight: 'ddanhs ker'...")
        typeSequence("ddanhs ker")
        Thread.sleep(forTimeInterval: 0.4)

        var spotTextVal: AnyObject?
        AXUIElementCopyAttributeValue(spotElem, kAXValueAttribute as CFString, &spotTextVal)
        let spotText = (spotTextVal as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        print("-> Spotlight text: '\(spotText)'")
        let spotPassed = (spotText == "đánh kẻ")
        print("-> Spotlight status: \(spotPassed ? "PASS" : "FAIL")")

        // Step 3: Close Spotlight
        print("\n[Step 3] Closing Spotlight (Esc)...")
        let escD = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Escape, keyDown: true)!
        let escU = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Escape, keyDown: false)!
        escD.post(tap: .cghidEventTap); escU.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.5)

        print("-> Is Spotlight on screen after Esc: \(isSpotlightVisible())")

        // Step 4: Focus Yandex and type in address bar
        print("\n[Step 4] Focusing Yandex Browser and typing in address bar...")
        let yandexApps = NSRunningApplication.runningApplications(withBundleIdentifier: "ru.yandex.desktop.yandex-browser")
        if let yandex = yandexApps.first {
            yandex.activate(options: .activateIgnoringOtherApps)
            Thread.sleep(forTimeInterval: 0.3)

            // Cmd+L to focus address bar
            let lDown = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_L, keyDown: true)!
            let lUp   = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_ANSI_L, keyDown: false)!
            lDown.flags = .maskCommand; lUp.flags = .maskCommand
            lDown.post(tap: .cghidEventTap); lUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.2)

            // Delete
            let delD = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: true)!
            let delU = CGEvent(keyboardEventSource: src, virtualKey: KeyConstants.kVK_Delete, keyDown: false)!
            delD.post(tap: .cghidEventTap); delU.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.2)

            print("[Step 5] Typing in Yandex address bar: 'chayj ddi' (verifying FIRST word 'chạy')...")
            typeSequence("chayj ddi")
            Thread.sleep(forTimeInterval: 0.5)

            let yandexElem = AXUIElementCreateApplication(yandex.processIdentifier)
            var focusedVal: AnyObject?
            AXUIElementCopyAttributeValue(yandexElem, kAXFocusedUIElementAttribute as CFString, &focusedVal)
            if let fElem = focusedVal as! AXUIElement? {
                var yTextVal: AnyObject?
                AXUIElementCopyAttributeValue(fElem, kAXValueAttribute as CFString, &yTextVal)
                let yText = (yTextVal as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                print("-> Yandex address bar text: '\(yText)'")
                let yPassed = yText.hasPrefix("chạy") || yText.contains("chạy đi")
                print("-> Yandex first word status: \(yPassed ? "PASS (Chữ đầu tiên không bị sai!)" : "FAIL")")
            }
        }

        print("\n==================================================================")
        print("CROSS-APP ISOLATION TEST FINISHED")
        print("==================================================================")
    }
}
