import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

// MARK: - KeyEventSender

/// Injects synthetic keyboard events (backspaces + Unicode text) into the
/// macOS Session or HID event stream, or performs direct AX replacement for overlay apps.
/// All events carry the SKEY marker so EventTapManager can recognise and skip them.
public final class KeyEventSender {
    // MARK: - Shared

    public static let shared = KeyEventSender()

    // MARK: - State

    private let source: CGEventSource?
    private let semaphore = DispatchSemaphore(value: 1)

    // MARK: - Init

    private init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    // MARK: - Public API

    /// Injects `backspaces` delete events followed by the Unicode `text`.
    /// Uses direct AX replacement for Spotlight overlay to guarantee zero backspace loss,
    /// and standard CGEvent synthesis for normal applications.
    public func inject(backspaces: Int, text: String) {
        semaphore.wait()
        defer { semaphore.signal() }

        skeyLog("[KeyEventSender] inject called: backspaces=\(backspaces), text='\(text)' (count=\(text.count))", category: .keyboard)

        // Strategy A: If target app is Spotlight, use direct AX replacement
        if AccessibilityContextReader.isSpotlightActive() {
            if AccessibilityContextReader.shared.replaceTextViaAX(backspaces: backspaces, text: text) {
                return
            }
        }

        guard let source else { return }

        // Strategy B: Standard CGEvent synthesis with non-coalesced event delivery
        sendBackspaces(backspaces, source: source)
        if !text.isEmpty {
            sendText(text, source: source)
        }
    }

    // MARK: - Private Event Delivery

    private func sendBackspaces(_ count: Int, source: CGEventSource) {
        guard count > 0 else { return }

        for _ in 0..<count {
            post(keyCode: KeyConstants.backspaceKeyCode, source: source)
            usleep(KeyConstants.interBackspaceDelayUs)
        }
        usleep(KeyConstants.settleDelayUs)
    }

    /// Zero-heap-allocation unicode string sender using atomic CGEvent delivery
    private func sendText(_ text: String, source: CGEventSource) {
        let utf16Count = text.utf16.count
        guard utf16Count > 0 else { return }

        let emit: (UnsafePointer<UniChar>, Int) -> Void = { basePtr, length in
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return }

            down.flags = [.maskNonCoalesced]
            up.flags = [.maskNonCoalesced]
            down.keyboardSetUnicodeString(stringLength: length, unicodeString: basePtr)
            // Note: Never set unicodeString on keyUp events! KeyUp is a release event;
            // setting unicodeString on keyUp causes Chromium/Electron/Safari to insert the text twice.

            self.stamp(down)
            self.stamp(up)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }

        if utf16Count <= 1024 {
            withUnsafeTemporaryAllocation(of: UniChar.self, capacity: utf16Count) { buffer in
                guard let basePtr = buffer.baseAddress else { return }
                var length = 0
                for codeUnit in text.utf16 {
                    basePtr[length] = codeUnit
                    length += 1
                }
                emit(basePtr, length)
            }
        } else {
            let unichars = Array(text.utf16)
            unichars.withUnsafeBufferPointer { buffer in
                guard let basePtr = buffer.baseAddress else { return }
                emit(basePtr, buffer.count)
            }
        }
    }

    /// Posts a single key-down + key-up pair stamped with the SKEY marker and fresh mach timestamp.
    private func post(keyCode: CGKeyCode, source: CGEventSource) {
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        down.flags = [.maskNonCoalesced]
        up.flags = [.maskNonCoalesced]
        stamp(down); stamp(up)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    @inline(__always)
    private func stamp(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: KeyConstants.eventMarker)
        event.timestamp = mach_absolute_time()
    }
}
