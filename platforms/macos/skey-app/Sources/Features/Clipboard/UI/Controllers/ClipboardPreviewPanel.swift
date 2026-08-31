import AppKit
import SwiftUI

// MARK: - Native NSPopover Preview Controller

@MainActor
public final class ClipboardPreviewPopover: NSObject {
    private let popover = NSPopover()
    private var hostingController: NSHostingController<FloatingPreviewRootView>?
    private weak var currentParentView: NSView?

    public override init() {
        super.init()
        popover.behavior = .semitransient
        popover.animates = false
    }

    public var isShown: Bool {
        popover.isShown
    }

    public var panel: NSPanel? {
        popover.contentViewController?.view.window as? NSPanel
    }

    public func show(
        viewModel: ClipboardHistoryViewModel,
        relativeTo rect: NSRect,
        of parentView: NSView,
        preferredEdge: NSRectEdge,
        onClose: @escaping () -> Void
    ) {
        guard let window = parentView.window, window.isVisible else {
            close()
            return
        }

        let rootView = FloatingPreviewRootView(viewModel: viewModel, onClose: onClose)
        if let controller = hostingController {
            controller.rootView = rootView
        } else {
            let controller = NSHostingController(rootView: rootView)
            controller.view.frame = NSRect(x: 0, y: 0, width: 440, height: 480)
            popover.contentViewController = controller
            hostingController = controller
        }

        currentParentView = parentView

        if !popover.isShown {
            popover.show(relativeTo: rect, of: parentView, preferredEdge: preferredEdge)
        } else {
            if popover.contentViewController?.view.window != nil {
                popover.positioningRect = rect
            } else {
                popover.show(relativeTo: rect, of: parentView, preferredEdge: preferredEdge)
            }
        }
    }

    public func close() {
        if popover.isShown {
            popover.close()
        }
    }
}

// MARK: - Floating Preview Root View

public struct FloatingPreviewRootView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let onClose: () -> Void

    public init(viewModel: ClipboardHistoryViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.pasteStackSelected, !viewModel.pasteStackItems.isEmpty {
                PasteStackPreviewView(items: viewModel.pasteStackItems)
            } else if let item = viewModel.activePreviewItem {
                ClipboardPreviewItemView(viewModel: viewModel, item: item)
            } else {
                emptyView
            }
        }
        .padding(16)
        .frame(width: 440, height: 480)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "sidebar.right")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text("Không có nội dung xem trước")
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
