import AppKit
import SwiftUI

// MARK: - Large Text Preview (Optimized NSTextView)

public struct LargeTextPreviewView: NSViewRepresentable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 12.5)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }
}

// MARK: - Premium Glassmorphic Clipboard Preview View

public struct ClipboardPreviewItemView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let item: ClipboardItem

    @State private var fullImage: NSImage?
    @State private var imageFailed = false

    public init(viewModel: ClipboardHistoryViewModel, item: ClipboardItem) {
        self.viewModel = viewModel
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBar

            mainContentCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            metadataCard
        }
        .task(id: item.id) {
            imageFailed = false
            fullImage = nil
            guard item.contentType == .image else { return }
            fullImage = await viewModel.fullImage(for: item)
            if fullImage == nil {
                imageFailed = true
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: contentTypeIcon)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(contentTypeLabel)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )

            if let hexColor = detectedHexColor {
                HStack(spacing: 4) {
                    Circle()
                        .fill(hexColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                    Text(item.previewText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                .clipShape(Capsule())
            }

            Spacer()

            if let stats = contentStats {
                Text(stats)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Main Content Canvas

    private var mainContentCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                )

            Group {
                if item.contentType == .image {
                    imagePreview
                } else {
                    textPreview
                }
            }
            .padding(10)
        }
    }

    // MARK: - Image Preview

    @ViewBuilder
    private var imagePreview: some View {
        if let fullImage {
            VStack(spacing: 6) {
                Image(nsImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 1.5)

                Text("\(Int(fullImage.size.width)) × \(Int(fullImage.size.height)) px")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if imageFailed {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundColor(.secondary)
                Text(L10n(.previewImageFailed))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Text Preview

    @ViewBuilder
    private var textPreview: some View {
        let rawText = (item.textContent ?? item.previewText)
            .replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)

        if rawText.count >= ClipboardPopupUI.largeTextThreshold {
            LargeTextPreviewView(text: rawText)
                .id("textpreview-\(item.id)")
        } else {
            ScrollView {
                if let attributed = try? AttributedString(markdown: rawText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.system(size: 12.5, design: isLikelyCode(rawText) ? .monospaced : .default))
                        .foregroundColor(.primary)
                        .lineSpacing(3.5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    Text(rawText)
                        .font(.system(size: 12.5, design: isLikelyCode(rawText) ? .monospaced : .default))
                        .foregroundColor(.primary)
                        .lineSpacing(3.5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                if let bundleID = item.sourceBundleID {
                    if let icon = viewModel.appIcon(for: bundleID) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5))
                    }
                    if let name = viewModel.appName(for: bundleID) {
                        Text(name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(L10n(.previewUnknownApp))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                    Text("\(item.copyCount)")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                .clipShape(Capsule())
            }

            Divider().opacity(0.5)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n(.previewFirstCopyTime))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(formatDate(item.firstCopiedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n(.previewLastCopyTime))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(formatDate(item.capturedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
            }

            Divider().opacity(0.5)

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    kbdBadge("⌥P")
                    Text(L10n(.previewShortcutPin))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 3) {
                    kbdBadge("⌥⌫")
                    Text(L10n(.previewShortcutDelete))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    private func kbdBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 3.5))
            .overlay(
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 0.5)
    }

    private var contentTypeIcon: String {
        switch item.contentType {
        case .image: return "photo"
        case .fileReference: return "doc.text"
        default:
            if detectedHexColor != nil {
                return "paintpalette"
            }
            let text = item.previewText
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                return "link"
            }
            if isLikelyCode(text) {
                return "curlybraces"
            }
            return item.contentType == .richText ? "text.badge.plus" : "text.alignleft"
        }
    }

    private var contentTypeLabel: String {
        switch item.contentType {
        case .image: return L10n(.previewImage)
        case .fileReference: return L10n(.previewFile)
        default:
            if detectedHexColor != nil {
                return L10n(.previewColor)
            }
            let text = item.previewText
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                return L10n(.previewLink)
            }
            if isLikelyCode(text) {
                return L10n(.previewCode)
            }
            return item.contentType == .richText ? L10n(.previewRichText) : L10n(.previewText)
        }
    }

    private var contentStats: String? {
        if item.contentType == .image { return nil }
        let text = item.textContent ?? item.previewText
        let charCount = text.count
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        if charCount > 0 {
            return String(format: L10n("preview.stats"), wordCount, charCount)
        }
        return nil
    }

    private var detectedHexColor: Color? {
        let trimmed = item.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#"), trimmed.count == 7 || trimmed.count == 9 else { return nil }
        let scanner = Scanner(string: String(trimmed.dropFirst()))
        var hexNumber: UInt64 = 0
        if scanner.scanHexInt64(&hexNumber) {
            let r = Double((hexNumber & 0xff0000) >> 16) / 255
            let g = Double((hexNumber & 0x00ff00) >> 8) / 255
            let b = Double(hexNumber & 0x0000ff) / 255
            return Color(red: r, green: g, blue: b)
        }
        return nil
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private func isLikelyCode(_ text: String) -> Bool {
        let codeIndicators = ["func ", "let ", "var ", "import ", "const ", "class ", "def ", "return ", "{", "}", ";", "=>", "struct "]
        return codeIndicators.contains(where: { text.contains($0) })
    }
}
