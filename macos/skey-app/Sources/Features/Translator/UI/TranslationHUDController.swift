import AppKit
import SwiftUI

// MARK: - Native Floating Translation Panel

public final class TranslationHUDPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    // Enable standard macOS editing shortcuts (Cmd+A, Cmd+C, Cmd+V, Cmd+X, Cmd+Z)
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v":
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "z":
                if event.modifierFlags.contains(.shift) {
                    return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
                } else {
                    return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - TranslationHUDController

public final class TranslationHUDController: NSWindowController {
    public static let shared = TranslationHUDController()

    private var localMonitor: Any?

    private init() {
        let panel = TranslationHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380)
        )
        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func toggleHUD(initialText: String? = nil) {
        if let window = self.window, window.isVisible {
            hideHUD()
        } else {
            showHUD(initialText: initialText)
        }
    }

    public func showHUD(initialText: String? = nil) {
        guard let window = self.window else { return }

        let rootView = TranslationHUDView(initialText: initialText) { [weak self] in
            self?.hideHUD()
        }
        window.contentView = NSHostingView(rootView: rootView)

        // Center on screen or near mouse
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) {
            let x = min(max(mouseLocation.x - 280, screen.visibleFrame.minX + 20), screen.visibleFrame.maxX - 580)
            let y = min(max(mouseLocation.y - 190, screen.visibleFrame.minY + 20), screen.visibleFrame.maxY - 400)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        setupKeyboardMonitor()
    }

    public func hideHUD() {
        guard let window = self.window else { return }
        window.orderOut(nil)
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func setupKeyboardMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.hideHUD()
                return nil
            }
            return event
        }
    }
}
