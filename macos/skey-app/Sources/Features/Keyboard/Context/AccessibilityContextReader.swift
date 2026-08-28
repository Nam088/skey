import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

// MARK: - AccessibilityContextReader

/// Reads and manipulates text in the currently focused UI element using the macOS Accessibility API.
/// 100% crash-proof with stack allocation, CFTypeID validation, and Unicode boundary handling.
public final class AccessibilityContextReader {
    public static let shared = AccessibilityContextReader()

    private init() {}

    /// Checks if Spotlight's search window is actually visible on screen.
    public static func isSpotlightActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for w in windowList {
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            if owner == "Spotlight" && layer > 0 {
                return true
            }
        }
        return false
    }

    /// Returns true if the currently focused UI element has an active text selection
    /// (e.g. Chrome Omnibox / Safari Address Bar inline autocomplete suggestion).
    public func hasActiveSelection() -> Bool {
        guard let axElement = getFocusedElement(isSpotlight: false) else { return false }
        guard let range = getSelectedRange(for: axElement) else { return false }
        return range.length > 0
    }

    /// Directly replaces `backspaces` characters preceding the cursor with `text` via Accessibility API.
    /// Exclusively applies to Spotlight overlay search field.
    /// Returns true if successful, allowing callers to bypass synthetic CGEvent backspaces completely.
    public func replaceTextViaAX(backspaces: Int, text: String) -> Bool {
        guard Self.isSpotlightActive(), let axElem = getFocusedElement(isSpotlight: true) else {
            return false
        }

        var rangeVal: AnyObject?
        guard AXUIElementCopyAttributeValue(axElem, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success,
              let val = rangeVal, CFGetTypeID(val) == AXValueGetTypeID() else {
            return false
        }
        var currentRange = CFRange(location: 0, length: 0)
        // swiftlint:disable:next force_cast
        guard AXValueGetValue((val as! AXValue), .cfRange, &currentRange) else {
            return false
        }

        let replaceLoc = max(0, currentRange.location - backspaces)
        let replaceLen = backspaces + currentRange.length
        var targetRange = CFRange(location: replaceLoc, length: replaceLen)

        guard let targetVal = AXValueCreate(.cfRange, &targetRange) else { return false }
        guard AXUIElementSetAttributeValue(axElem, kAXSelectedTextRangeAttribute as CFString, targetVal) == .success else {
            return false
        }

        guard AXUIElementSetAttributeValue(axElem, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success else {
            return false
        }

        var newCaret = CFRange(location: replaceLoc + text.utf16.count, length: 0)
        if let caretVal = AXValueCreate(.cfRange, &newCaret) {
            _ = AXUIElementSetAttributeValue(axElem, kAXSelectedTextRangeAttribute as CFString, caretVal)
        }

        return true
    }

    /// Extracts the word immediately preceding the cursor in the currently focused UI element.
    public func getPrecedingWord() -> String? {
        guard let axElement = getFocusedElement() else {
            return nil
        }

        // Fast Role validation: Filter out non-text UI containers and read-only static text elements early
        var roleVal: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleVal) == .success,
           let role = roleVal as? String {
            if role == (kAXButtonRole as String) ||
               role == (kAXWindowRole as String) ||
               role == (kAXListRole as String) ||
               role == (kAXTableRole as String) ||
               role == (kAXScrollBarRole as String) ||
               role == (kAXStaticTextRole as String) ||
               role == "AXHeading" ||
               role == "AXImage" ||
               role == "AXLink" ||
               role == "AXCell" ||
               role == "AXRow" ||
               role == "AXColumn" ||
               role == "AXWebArea" ||
               role == "AXGroup" {
                return nil
            }
        }

        // 1. Must have a valid SelectedTextRange with a caret (length == 0 and location > 0)
        guard let range = getSelectedRange(for: axElement),
              range.length == 0,
              range.location > 0 else {
            return nil
        }

        // Strategy A: Parameterized attribute kAXStringForRangeParameterizedAttribute
        let readLen = min(range.location, 30)
        let startLoc = range.location - readLen
        var readRange = CFRange(location: startLoc, length: readLen)

        if let rangeValue = AXValueCreate(.cfRange, &readRange) {
            var stringVal: AnyObject?
            let paramErr = AXUIElementCopyParameterizedAttributeValue(
                axElement,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &stringVal
            )
            if paramErr == .success, let text = stringVal as? String, !text.isEmpty {
                if let word = extractLastWord(from: text) {
                    return word
                }
            }
        }

        // Strategy B: Read full kAXValueAttribute and slice up to range.location
        var valueAttr: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueAttr) == .success,
           let fullText = valueAttr as? String, !fullText.isEmpty {
            let location = min(range.location, fullText.utf16.count)
            let prefixIndex = fullText.utf16.index(fullText.utf16.startIndex, offsetBy: location, limitedBy: fullText.utf16.endIndex) ?? fullText.utf16.endIndex
            let prefixString = String(fullText.utf16[..<prefixIndex]) ?? ""
            if let word = extractLastWord(from: prefixString) {
                return word
            }
        }

        return nil
    }

    // MARK: - Focused Element Resolution

    public func getFocusedElement(isSpotlight: Bool? = nil) -> AXUIElement? {
        let spotActive = isSpotlight ?? Self.isSpotlightActive()
        let pid: pid_t
        if spotActive {
            let spotApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight")
            pid = spotApps.first?.processIdentifier ?? 0
        } else {
            let obsPID = AppFocusObserver.shared.currentPID
            pid = obsPID > 0 ? obsPID : (NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
        }

        if pid > 0 {
            let appElement = AXUIElementCreateApplication(pid)
            var focusedVal: AnyObject?
            if AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedVal
            ) == .success,
            let element = focusedVal,
            CFGetTypeID(element) == AXUIElementGetTypeID() {
                // swiftlint:disable:next force_cast
                return (element as! AXUIElement)
            }
        }

        // Fallback: SystemWide query
        let systemWide = AXUIElementCreateSystemWide()
        var directVal: AnyObject?
        if AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &directVal
        ) == .success,
        let element = directVal,
        CFGetTypeID(element) == AXUIElementGetTypeID() {
            // swiftlint:disable:next force_cast
            return (element as! AXUIElement)
        }

        return nil
    }

    public func getSelectedRange(for element: AXUIElement) -> CFRange? {
        var rangeVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success,
           let axValue = rangeVal,
           CFGetTypeID(axValue) == AXValueGetTypeID() {
            var range = CFRange(location: 0, length: 0)
            // swiftlint:disable:next force_cast
            if AXValueGetValue((axValue as! AXValue), .cfRange, &range) {
                return range
            }
        }
        return nil
    }

    /// Extracts the contiguous non-whitespace word characters from the end of the text.
    private func extractLastWord(from text: String) -> String? {
        guard let lastChar = text.last, !isWordBoundary(lastChar) else {
            return nil
        }

        var wordScalars: [Unicode.Scalar] = []
        wordScalars.reserveCapacity(16)

        for scalar in text.unicodeScalars.reversed() {
            let char = Character(scalar)
            if isWordBoundary(char) {
                break
            }
            wordScalars.append(scalar)
            if wordScalars.count >= 15 {
                break
            }
        }

        guard !wordScalars.isEmpty else { return nil }
        return String(String.UnicodeScalarView(wordScalars.reversed()))
    }

    /// High-performance inline character classifier for word boundaries.
    @inline(__always)
    private func isWordBoundary(_ char: Character) -> Bool {
        if char.isWhitespace || char.isPunctuation || char.isNewline {
            return true
        }
        guard let scalar = char.unicodeScalars.first, char.unicodeScalars.count == 1 else {
            return false
        }
        let val = scalar.value
        return val == 0x00A0 || val == 0x200B || val == 0x200C || val == 0x200D || val == 0xFEFF
    }
}
