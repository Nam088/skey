import AppKit
import Foundation

// MARK: - ClipboardFeature

/// Feature module providing Maccy/Raycast-like Clipboard History management with Floating Popup
public final class ClipboardFeature: NSObject, Feature {
    public static let shared = ClipboardFeature()

    public let id = "com.nam088.skey.feature.clipboard"
    public var name: String { L10n(.clipboardMenu) }

    public var isEnabled: Bool { AppSettings.shared.clipboard.isEnabled }

    public let store: ClipboardStore
    private let monitor = ClipboardMonitor.shared
    public private(set) var popupController: ClipboardHistoryPopupController?

    public override init() {
        self.store = ClipboardStore()
        super.init()
    }

    // MARK: - Feature Lifecycle

    public func start() {
        guard isEnabled else { return }

        // Setup Popup Controller on MainActor
        MainActor.assumeIsolated {
            self.popupController = ClipboardHistoryPopupController(
                store: store,
                onPasteSelection: { [weak self] items, asPlainText in
                    self?.handlePaste(items: items, asPlainText: asPlainText)
                }
            )
        }

        // Start background pasteboard monitor
        monitor.startMonitoring { [weak self] captured in
            guard let self else { return }
            Task {
                try? await self.store.capture(captured)
            }
        }

        skeyLog("ClipboardFeature started with Floating Popup UI", category: .clipboard)
    }

    public func stop() {
        monitor.stopMonitoring()
        MainActor.assumeIsolated {
            self.popupController?.close()
        }
        skeyLog("ClipboardFeature stopped", category: .clipboard)
    }

    // MARK: - Public Actions

    public func togglePopup(relativeTo button: NSStatusBarButton? = nil) {
        guard isEnabled else { return }
        MainActor.assumeIsolated {
            self.popupController?.toggle(relativeTo: button)
        }
    }

    public func showPopup(relativeTo button: NSStatusBarButton? = nil) {
        guard isEnabled else { return }
        MainActor.assumeIsolated {
            self.popupController?.show(relativeTo: button)
        }
    }

    public func hidePopup() {
        MainActor.assumeIsolated {
            self.popupController?.close()
        }
    }

    // MARK: - Paste Handler

    private func handlePaste(items: [ClipboardItem], asPlainText: Bool) {
        guard !items.isEmpty else { return }

        Task {
            if items.count == 1, let item = items.first {
                let payload = await store.loadPayloadData(for: item)
                await MainActor.run {
                    ClipboardMonitor.copyToPasteboard(item, payloadData: payload, asPlainText: asPlainText)
                    self.triggerSystemPaste()
                }
            } else {
                // Multi-item Paste Stack: concatenate text
                let combinedText = items.compactMap { $0.textContent ?? $0.previewText }.joined(separator: "\n")
                await MainActor.run {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(combinedText, forType: .string)
                    self.triggerSystemPaste()
                }
            }
        }
    }

    private func triggerSystemPaste() {
        // Short delay to allow target application to regain active window focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            source.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitLocalKeyboardEvents], state: .eventSuppressionStateSuppressionInterval)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: KeyConstants.kVK_ANSI_V, keyDown: true)
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: KeyConstants.kVK_ANSI_V, keyDown: false)

            keyDown?.flags = .maskCommand
            keyUp?.flags = []

            keyDown?.setIntegerValueField(.eventSourceUserData, value: KeyConstants.eventMarker)
            keyUp?.setIntegerValueField(.eventSourceUserData, value: KeyConstants.eventMarker)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Menu Builder

    public func buildMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        let openPopupItem = NSMenuItem(
            title: L10n(.clipboardMenu),
            action: #selector(openClipboardPopupClicked),
            keyEquivalent: "v"
        )
        openPopupItem.keyEquivalentModifierMask = [.option]
        openPopupItem.target = self
        items.append(openPopupItem)

        return items
    }

    @objc private func openClipboardPopupClicked() {
        togglePopup()
    }
}
