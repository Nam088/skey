import AppKit
import SwiftUI

// MARK: - List Item Row (Maccy-Style High Performance Item)

public struct ClipboardListItemView: View, Equatable {
    public let item: ClipboardItem
    public let index: Int
    public let isSelected: Bool
    public let selectionAppearance: SelectionAppearance
    public let attributedTitle: AttributedString
    public let appIcon: NSImage?
    public let thumbnail: NSImage?
    public let colorSwatchImage: NSImage?
    public let stackPosition: Int?
    public let showApplicationIcons: Bool
    public var imageThumbnailHeight: CGFloat = 40

    public let onHoverSelect: (UUID, Bool) -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onTap: () -> Void
    public let thumbnailLoader: () async -> NSImage?

    @State private var loadedThumbnail: NSImage?
    @State private var isHovered = false

    public static func == (lhs: ClipboardListItemView, rhs: ClipboardListItemView) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.item.isPinned == rhs.item.isPinned &&
        lhs.item.copyCount == rhs.item.copyCount &&
        lhs.isSelected == rhs.isSelected &&
        lhs.index == rhs.index &&
        lhs.selectionAppearance == rhs.selectionAppearance &&
        lhs.attributedTitle == rhs.attributedTitle &&
        lhs.appIcon == rhs.appIcon &&
        lhs.thumbnail == rhs.thumbnail &&
        lhs.colorSwatchImage == rhs.colorSwatchImage &&
        lhs.stackPosition == rhs.stackPosition &&
        lhs.showApplicationIcons == rhs.showApplicationIcons &&
        lhs.imageThumbnailHeight == rhs.imageThumbnailHeight
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Leading: App Icon
            if showApplicationIcons, let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(.leading, 6)
            } else {
                Spacer()
                    .frame(width: 6)
            }

            // Main Content: either large image thumbnail or leading accessory + title
            mainContentView

            Spacer(minLength: 4)

            // Trailing Accessories (Copy count, Pin badge, Hover actions, Shortcut)
            trailingAccessoriesView
        }
        .frame(minHeight: item.contentType == .image ? max(56, imageThumbnailHeight + 8) : ClipboardPopupUI.itemHeight)
        .padding(.vertical, item.contentType == .image ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.85)
                : (isHovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.4) : Color.white.opacity(0.001))
        )
        .clipShape(selectionAppearance.rect(cornerRadius: ClipboardPopupUI.cornerRadius))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            onHoverSelect(item.id, hovering)
        }
        .onTapGesture(perform: onTap)
        .task(id: item.id) {
            if item.contentType == .image && thumbnail == nil && loadedThumbnail == nil {
                loadedThumbnail = await thumbnailLoader()
            }
        }
    }

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        if item.contentType == .image {
            if let imageToDisplay = (thumbnail ?? loadedThumbnail) {
                Image(nsImage: imageToDisplay)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: max(50, imageThumbnailHeight))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 1.5, x: 0, y: 1)
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(attributedTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
        } else {
            HStack(spacing: 6) {
                leadingAccessoryView

                Text(attributedTitle)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Leading Accessory

    @ViewBuilder
    private var leadingAccessoryView: some View {
        if let colorSwatchImage {
            Image(nsImage: colorSwatchImage)
                .resizable()
                .frame(width: 12, height: 12)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
        } else if item.contentType == .fileReference {
            Image(systemName: "doc.fill")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
        } else if isLink(item.textContent) {
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
        }
    }

    // MARK: - Trailing Accessories

    @ViewBuilder
    private var trailingAccessoriesView: some View {
        HStack(spacing: 5) {
            // Multi-item Paste Stack position pill
            if let stackPosition {
                Text("\(stackPosition)")
                    .font(.system(size: 10, weight: .bold))
                    .frame(minWidth: 14, minHeight: 14)
                    .padding(.horizontal, 3)
                    .background(Color.white.opacity(isSelected ? 0.35 : 0.2), in: Capsule())
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }

            // Copy Count Badge
            if item.copyCount > 1 {
                Text("×\(item.copyCount)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(isSelected ? 0.3 : 0.15), in: Capsule())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
            }

            // Quick Pin / Delete Action Buttons
            if isHovered {
                HStack(spacing: 2) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10.5))
                            .foregroundStyle(item.isPinned ? Color.orange : (isSelected ? Color.white : Color.secondary))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.red.opacity(0.85))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white : Color.orange.opacity(0.9))
            }

            // Number Shortcut Badge (⌘1 ... ⌘9)
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary.opacity(0.7))
            }
        }
        .padding(.trailing, 8)
    }

    private func isLink(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.hasPrefix("http://") || text.hasPrefix("https://") else { return false }
        return true
    }
}
