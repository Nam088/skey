import AppKit
import SwiftUI

// MARK: - Paste Stack Preview

public struct PasteStackPreviewView: View {
    public let items: [ClipboardItem]

    public init(items: [ClipboardItem]) {
        self.items = items
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(pair.offset + 1)")
                            .font(.caption)
                            .frame(minWidth: 16, alignment: .center)
                            .padding(3)
                            .background(Color.secondary.opacity(0.8), in: Capsule())
                            .foregroundStyle(Color.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.element.previewText)
                                .font(.callout)
                                .lineLimit(3)

                            Text(ByteCountFormatter.string(fromByteCount: Int64(pair.element.payloadSizeBytes), countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                }
            }
            .padding(.top, 2)
        }
    }
}
