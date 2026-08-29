import AppKit
import SwiftUI

// MARK: - Clipboard History Popup Main Content View

public struct ClipboardHistoryContentView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let onClose: () -> Void
    @FocusState private var searchFieldFocused: Bool

    public init(viewModel: ClipboardHistoryViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
                )

            VStack(spacing: 0) {
                header
                historySection
                if viewModel.settings.showFooter {
                    ClipboardFooterView(viewModel: viewModel, onClose: onClose)
                }
            }
            .frame(width: ClipboardPopupUI.menuWidth)

            if viewModel.showClearConfirmation {
                ClipboardClearConfirmationView(viewModel: viewModel, isClearAll: false)
            } else if viewModel.showClearAllConfirmation {
                ClipboardClearConfirmationView(viewModel: viewModel, isClearAll: true)
            }
        }
        .frame(
            width: ClipboardPopupUI.menuWidth,
            height: viewModel.desiredHeight
        )
        .coordinateSpace(name: "clipboardPopupCoordinates")
        .onPreferenceChange(SelectedRowFramePreferenceKey.self) { rect in
            guard let rect, viewModel.selectedRowSwiftUIFrame != rect else { return }
            DispatchQueue.main.async {
                viewModel.selectedRowSwiftUIFrame = rect
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            viewModel.onCloseForAction = onClose
            // Delay focus to avoid competing with window entrance animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFieldFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        SearchFieldView(query: $viewModel.searchQuery) {
            viewModel.confirmSelection()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(spacing: 0) {
            if !viewModel.stackedItemIDs.isEmpty {
                PasteStackCollapsedView(
                    stackItems: viewModel.pasteStackItems,
                    totalCount: viewModel.stackedItemIDs.count,
                    isSelected: viewModel.pasteStackSelected,
                    onSelect: { viewModel.selectPasteStack() }
                )
                .padding(.horizontal, ClipboardPopupUI.horizontalSeparatorPadding)
                .padding(.top, ClipboardPopupUI.verticalSeparatorPadding)

                Divider()
                    .padding(.horizontal, ClipboardPopupUI.horizontalSeparatorPadding)
                    .padding(.vertical, ClipboardPopupUI.verticalSeparatorPadding)
            }

            if viewModel.settings.pinTo == .top {
                pinsSection(showsBottomSeparator: true)
            }

            listBody

            if viewModel.settings.pinTo == .bottom {
                pinsSection(showsBottomSeparator: false)
            }
        }
        // When the mouse leaves the entire list area (including to outside the window),
        // clear hover highlight and close any auto-opened preview.
        .onHover { hovering in
            if !hovering {
                viewModel.selectedItemID = nil
                viewModel.autoPreviewTask?.cancel()
                viewModel.isPreviewOpen = false
            }
        }
    }

    @ViewBuilder
    private func pinsSection(showsBottomSeparator: Bool) -> some View {
        if !viewModel.pinnedItems.isEmpty {
            Divider()
                .padding(.horizontal, ClipboardPopupUI.horizontalSeparatorPadding)
                .padding(.vertical, ClipboardPopupUI.verticalSeparatorPadding)

            pinRows

            if showsBottomSeparator && !viewModel.unpinnedItems.isEmpty {
                Divider()
                    .padding(.horizontal, ClipboardPopupUI.horizontalSeparatorPadding)
                    .padding(.vertical, 3)
            }
        }
    }

    @ViewBuilder
    private var listBody: some View {
        if viewModel.items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        historyRows
                    }
                    .padding(.horizontal, ClipboardPopupUI.horizontalPadding)
                    .padding(.top, ClipboardPopupUI.verticalSeparatorPadding)
                    .padding(.bottom, ClipboardPopupUI.verticalSeparatorPadding)
                }
                .onChange(of: viewModel.scrollTargetID) { _, targetID in
                    if let targetID {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: viewModel.searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text(viewModel.searchQuery.isEmpty ? L10n(.clipboardEmpty) : L10n(.clipboardNoMatches))
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 70)
        .padding(.vertical, 8)
    }

    private var historyRows: some View {
        let ordered = viewModel.displayOrder
        let indexMap = viewModel.indexMap
        return ForEach(viewModel.unpinnedItems) { item in
            row(for: item, in: ordered, indexMap: indexMap)
        }
    }

    private func row(for item: ClipboardItem, in ordered: [ClipboardItem], indexMap: [UUID: Int]) -> some View {
        let index = indexMap[item.id] ?? 0
        let isSelected = viewModel.selectedItemID == item.id
        let previousSelected = index > 0 && viewModel.stackedItemIDs.contains(ordered[index - 1].id)
        let nextSelected = index < ordered.count - 1 && viewModel.stackedItemIDs.contains(ordered[index + 1].id)
        let selectionAppearance: SelectionAppearance = {
            switch (previousSelected, nextSelected) {
            case (true, false): return .topConnection
            case (false, true): return .bottomConnection
            case (true, true): return .topBottomConnection
            default: return .none
            }
        }()
        let thumbnail = item.contentType == .image ? viewModel.cachedThumbnail(for: item) : nil

        return ClipboardListItemView(
            item: item,
            index: index,
            isSelected: isSelected,
            selectionAppearance: selectionAppearance,
            attributedTitle: viewModel.attributedTitle(for: item),
            appIcon: viewModel.appIcon(for: item.sourceBundleID),
            thumbnail: thumbnail,
            colorSwatchImage: thumbnail == nil ? viewModel.colorSwatch(for: item) : nil,
            stackPosition: viewModel.stackPosition(of: item),
            showApplicationIcons: viewModel.settings.showApplicationIcons,
            imageThumbnailHeight: CGFloat(viewModel.settings.imageThumbnailHeight),
            onHoverSelect: { id, hovering in viewModel.selectOnHover(id: id, hovering: hovering) },
            onTogglePin: { Task { await viewModel.togglePin(item) } },
            onDelete: { Task { await viewModel.delete(item) } },
            onTap: {
                if NSEvent.modifierFlags.contains(.command) {
                    viewModel.toggleStack(item)
                } else {
                    viewModel.selectRow(item)
                }
            },
            thumbnailLoader: { await viewModel.fullImage(for: item) }
        )
        .equatable()
        .contextMenu {
            Button {
                viewModel.selectRow(item, asPlainText: false)
            } label: {
                Label(L10n(.clipboardPaste), systemImage: "doc.on.clipboard")
            }

            if item.contentType == .richText || item.contentType == .plainText {
                Button {
                    viewModel.selectRow(item, asPlainText: true)
                } label: {
                    Label(L10n(.clipboardPasteAsPlainText), systemImage: "text.alignleft")
                }
            }

            Divider()

            Button {
                Task { await viewModel.togglePin(item) }
            } label: {
                Label(
                    item.isPinned ? L10n(.clipboardUnpin) : L10n(.clipboardPin),
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Label(L10n(.clipboardDelete), systemImage: "trash")
            }
        }
        .background {
            if isSelected {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: SelectedRowFramePreferenceKey.self,
                        value: geo.frame(in: .named("clipboardPopupCoordinates"))
                    )
                }
            }
        }
        .id(item.id)
    }

    @ViewBuilder
    private var pinRows: some View {
        let ordered = viewModel.displayOrder
        let indexMap = viewModel.indexMap
        LazyVStack(spacing: 0) {
            ForEach(viewModel.pinnedItems) { item in
                row(for: item, in: ordered, indexMap: indexMap)
            }
        }
        .padding(.horizontal, ClipboardPopupUI.horizontalPadding)
    }
}

// MARK: - Preference Key

private struct SelectedRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() {
            value = next
        }
    }
}
