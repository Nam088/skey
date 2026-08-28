import AppKit
import SwiftUI

// MARK: - Footer (Views/FooterView.swift Parity)

public struct ClipboardFooterView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let onClose: () -> Void

    @State private var showClear = true
    @State private var showClearAll = false

    public init(viewModel: ClipboardHistoryViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, ClipboardPopupUI.horizontalSeparatorPadding)
                .padding(.bottom, ClipboardPopupUI.verticalSeparatorPadding)

            ZStack {
                ClipboardFooterActionRow(
                    title: L10n(.clearClipboard),
                    shortcut: "⌘⌥⌫"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.requestClear()
                    }
                }
                .invisible(!showClear)

                ClipboardFooterActionRow(
                    title: L10n(.clearAllClipboard),
                    shortcut: "⌘⌥⇧⌫"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.requestClearAll()
                    }
                }
                .invisible(!showClearAll)
            }
            .onChange(of: viewModel.currentModifierFlags) { _, _ in
                showClear = !viewModel.clearAllModifiersPressed
                showClearAll = viewModel.clearAllModifiersPressed
            }

            ClipboardFooterActionRow(title: L10n(.clipboardSettings), shortcut: "⌘,") {
                viewModel.openPreferences()
            }

            ClipboardFooterActionRow(title: L10n(.clipboardAbout)) {
                showAbout()
            }

            ClipboardFooterActionRow(title: L10n(.clipboardQuit), shortcut: "⌘Q") {
                onClose()
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, ClipboardPopupUI.horizontalPadding)
        .padding(.bottom, ClipboardPopupUI.verticalPadding)
    }

    private func showAbout() {
        onClose()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SKey"
        alert.informativeText = "Bộ gõ tiếng Việt siêu nhẹ & Clipboard Manager thông minh cho macOS.\nPhiên bản 1.0.0"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Footer Action Row

public struct ClipboardFooterActionRow: View {
    public let title: String
    public let shortcut: String?
    public let action: () -> Void
    @State private var isHovered = false

    public init(title: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? Color.white : Color(nsColor: .labelColor))
                Spacer()
                if let shortcut {
                    HStack(spacing: 1) {
                        ForEach(Array(shortcut.unicodeScalars), id: \.self) { scalar in
                            Text(String(scalar))
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color(nsColor: .secondaryLabelColor))
                    .opacity(0.7)
                }
            }
            .frame(minHeight: ClipboardPopupUI.itemHeight)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: ClipboardPopupUI.cornerRadius, style: .continuous)
                    .fill(isHovered ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.001))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
