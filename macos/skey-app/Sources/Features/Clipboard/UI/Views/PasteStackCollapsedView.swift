import AppKit
import SwiftUI

// MARK: - Paste Stack Collapsed Cards

public struct PasteStackCollapsedView: View {
    public let stackItems: [ClipboardItem]
    public let totalCount: Int
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(stackItems: [ClipboardItem], totalCount: Int, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.stackItems = stackItems
        self.totalCount = totalCount
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(stackItems.prefix(3).enumerated()), id: \.element.id) { pair in
                card(pair.element, index: pair.offset)
                    .offset(y: CGFloat(pair.offset) * 4)
                    .scaleEffect(pow(0.98, Double(pair.offset)), anchor: .center)
                    .opacity(pair.offset == 0 ? 1 : pow(0.95, Double(pair.offset)))
                    .zIndex(Double(-pair.offset))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private func card(_ item: ClipboardItem, index: Int) -> some View {
        HStack(spacing: 6) {
            if index == 0 && totalCount > 1 {
                Text("\(totalCount - 1)")
                    .font(.caption)
                    .frame(minWidth: 10, alignment: .center)
                    .padding(3)
                    .background(Color.secondary.opacity(0.8), in: Capsule())
                    .foregroundStyle(Color.white)
            }

            Text(item.previewText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .foregroundStyle(index == 0 && isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(height: ClipboardPopupUI.itemHeight)
        .background(
            RoundedRectangle(cornerRadius: ClipboardPopupUI.cornerRadius, style: .continuous)
                .fill(index == 0 && isSelected
                    ? AnyShapeStyle(Color.accentColor.opacity(0.8))
                    : AnyShapeStyle(Color(nsColor: .tertiarySystemFill).opacity(0.9)))
        )
        .shadow(color: Color.black.opacity(index == 0 ? 0.1 : 0.05), radius: 2, y: 2)
    }
}
