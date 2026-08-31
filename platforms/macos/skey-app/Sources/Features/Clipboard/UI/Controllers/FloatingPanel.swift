import AppKit

// MARK: - Native Floating Panel (NSPanel Subclass)

public final class FloatingPanel: NSPanel {
    private let onClose: () -> Void

    public init(contentRect: NSRect, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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
        self.animationBehavior = .none
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}
