import AppKit
import SwiftUI

// MARK: - Slideout Content (Toolbar + Content Preview)

public struct SlideoutContentView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let onClose: () -> Void

    public init(viewModel: ClipboardHistoryViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 6) {
            ClipboardToolbarView(viewModel: viewModel)

            if viewModel.pasteStackSelected, !viewModel.pasteStackItems.isEmpty {
                PasteStackPreviewView(items: viewModel.pasteStackItems)
            } else if let item = viewModel.activePreviewItem {
                ClipboardPreviewItemView(viewModel: viewModel, item: item)
            } else {
                emptyPreview
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyPreview: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "sidebar.right")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text(L10n(.previewEmpty))
                .font(.system(size: 11.5))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toolbar View

public struct ClipboardToolbarView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel

    public init(viewModel: ClipboardHistoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                Image(systemName: headerIcon)
                    .font(.system(size: 10, weight: .medium))
                Text(headerTitle)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.secondary)

            Spacer()

            if viewModel.pasteStackSelected {
                ToolbarIconButton(
                    icon: "stop",
                    helpText: L10n(.clipboardPasteStackRemove),
                    isDestructive: true
                ) {
                    viewModel.removePasteStack()
                }
            } else if let item = viewModel.activePreviewItem {
                HStack(spacing: 4) {
                    ToolbarIconButton(
                        icon: item.isPinned ? "pin.slash.fill" : "pin",
                        helpText: item.isPinned ? L10n(.clipboardUnpin) : L10n(.clipboardPin),
                        isActive: item.isPinned
                    ) {
                        Task { await viewModel.togglePin(item) }
                    }

                    ToolbarIconButton(
                        icon: "trash",
                        helpText: L10n(.clipboardDelete),
                        isDestructive: true
                    ) {
                        Task { await viewModel.delete(item) }
                    }
                }
            }
        }
        .frame(height: 24)
    }

    private var headerTitle: String {
        if viewModel.pasteStackSelected {
            return L10n(.clipboardPasteStackTitle)
        }
        guard let item = viewModel.activePreviewItem else { return L10n(.previewTitle) }
        return item.contentType == .image ? L10n(.previewImage) : L10n(.previewText)
    }

    private var headerIcon: String {
        if viewModel.pasteStackSelected {
            return "square.stack.3d.up"
        }
        guard let item = viewModel.activePreviewItem else { return "eye" }
        return item.contentType == .image ? "photo" : "doc.text"
    }
}

// MARK: - Toolbar Icon Button Component

private struct ToolbarIconButton: View {
    let icon: String
    let helpText: String
    var isActive: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
    }

    private var iconColor: Color {
        if isActive { return .accentColor }
        if isHovered { return isDestructive ? .red : .primary }
        return .secondary
    }

    private var backgroundColor: Color {
        if isHovered {
            return isDestructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.08)
        }
        return Color.clear
    }
}
