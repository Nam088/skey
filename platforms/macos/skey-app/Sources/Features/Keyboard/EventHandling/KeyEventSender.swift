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

    /// Zero-heap-allocation unicode string sender using stack buffers
    private func sendText(_ text: String, source: CGEventSource) {
        let utf16Count = text.utf16.count
        guard utf16Count > 0 else { return }

        let chunkSize = 20
        withUnsafeTemporaryAllocation(of: UniChar.self, capacity: max(utf16Count, chunkSize)) { buffer in
            guard let basePtr = buffer.baseAddress else { return }

            var length = 0
            for codeUnit in text.utf16 {
                basePtr[length] = codeUnit
                length += 1
            }

            var offset = 0
            while offset < length {
                let currentChunkLen = min(chunkSize, length - offset)
                let chunkPtr = basePtr.advanced(by: offset)

                guard
                    let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                    let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                else { break }

                down.flags = [.maskNonCoalesced]
                up.flags = [.maskNonCoalesced]
                down.keyboardSetUnicodeString(stringLength: currentChunkLen, unicodeString: chunkPtr)
                up.keyboardSetUnicodeString(stringLength: currentChunkLen, unicodeString: chunkPtr)

                stamp(down); stamp(up)
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)

                offset += currentChunkLen
                if offset < length {
                    usleep(KeyConstants.interChunkDelayUs)
                }
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
