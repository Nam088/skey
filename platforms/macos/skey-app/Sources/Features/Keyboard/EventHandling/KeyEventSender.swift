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

    /// Zero-heap-allocation unicode string sender: one CGEvent per grapheme cluster.
    ///
    /// A single CGEvent carrying a multi-character unicode string is delivered intact by
    /// AppKit and Chromium, but Qt 6 hosts drop the whole event and insert nothing. That
    /// silently ate every multi-character replacement the engine produced: typing
    /// "ddanhs kexr chayj" in TeXstudio yielded "đh kẻ ch" because the 'án', 'ẻ' and 'ạy'
    /// events never arrived while their backspaces did. Measured on TeXstudio 4.9.7 (Qt 6):
    /// one event per cluster is correct on every case, one event per string fails on every
    /// case longer than a single character, macros included.
    ///
    /// One event per cluster is also what a physical keyboard produces, so no toolkit has a
    /// reason to reject it. Clusters rather than UTF-16 units: splitting mid-cluster would
    /// emit lone surrogates for non-BMP characters and orphan combining marks.
    ///
    /// No inter-event delay. Events posted to the same tap keep their order, and 85
    /// characters cost ~7ms this way versus ~123ms with a 1ms spacing.
    private func sendText(_ text: String, source: CGEventSource) {
        guard !text.isEmpty else { return }

        // Below the threshold the two strategies are indistinguishable in practice: a
        // three-character replacement costs ~118µs one character at a time against ~49µs
        // packed, both invisible next to the ~60ms that separates two real keystrokes.
        // Every Vietnamese tone or vowel transform lands here, so it always takes the path
        // that works everywhere and never consults the frontmost app.
        //
        // Long text is where the difference becomes real: 400 characters cost ~33ms one at
        // a time against ~38µs packed. Macro expansion is the only thing that reaches this
        // size, and only there is it worth asking whether the app can take a packed event.
        if text.count > Self.packedDeliveryThreshold,
           !AppFocusObserver.shared.currentNeedsPerCharacterInjection {
            sendPacked(text, source: source)
            return
        }

        for cluster in text {
            sendCluster(cluster, source: source)
        }
    }

    /// Length beyond which a packed single event is worth using on apps that accept it.
    ///
    /// Chosen so that everything below stays under a millisecond per character path
    /// (~638µs at 27 characters), which keeps the fast path out of the typing hot path
    /// entirely and confines it to macro expansion.
    private static let packedDeliveryThreshold = 32

    /// Emits the whole string in one CGEvent.
    ///
    /// Only for apps proven to accept multi-character unicode strings. Qt hosts drop such an
    /// event wholesale, which is the bug this file's `sendCluster` path exists to avoid, so
    /// never call this without checking `needsPerCharacterInjection` first.
    private func sendPacked(_ text: String, source: CGEventSource) {
        let utf16Count = text.utf16.count
        guard utf16Count > 0 else { return }
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        down.flags = [.maskNonCoalesced]
        up.flags = [.maskNonCoalesced]

        withUnsafeTemporaryAllocation(of: UniChar.self, capacity: utf16Count) { buffer in
            guard let basePtr = buffer.baseAddress else { return }
            var length = 0
            for codeUnit in text.utf16 {
                basePtr[length] = codeUnit
                length += 1
            }
            down.keyboardSetUnicodeString(stringLength: length, unicodeString: basePtr)
            // Note: Never set unicodeString on keyUp events! KeyUp is a release event;
            // setting unicodeString on keyUp causes Chromium/Electron/Safari to insert the text twice.
        }

        stamp(down)
        stamp(up)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    /// Posts one grapheme cluster as a single key-down + key-up pair.
    private func sendCluster(_ cluster: Character, source: CGEventSource) {
        let utf16Count = cluster.utf16.count
        guard utf16Count > 0 else { return }
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        down.flags = [.maskNonCoalesced]
        up.flags = [.maskNonCoalesced]

        withUnsafeTemporaryAllocation(of: UniChar.self, capacity: utf16Count) { buffer in
            guard let basePtr = buffer.baseAddress else { return }
            var length = 0
            for codeUnit in cluster.utf16 {
                basePtr[length] = codeUnit
                length += 1
            }
            down.keyboardSetUnicodeString(stringLength: length, unicodeString: basePtr)
            // Note: Never set unicodeString on keyUp events! KeyUp is a release event;
            // setting unicodeString on keyUp causes Chromium/Electron/Safari to insert the text twice.
        }

        stamp(down)
        stamp(up)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
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
