import AppKit
import SwiftUI

// MARK: - In-Panel Clear Confirmation Dialog View

public struct ClipboardClearConfirmationView: View {
    @ObservedObject public var viewModel: ClipboardHistoryViewModel
    public let isClearAll: Bool

    public init(viewModel: ClipboardHistoryViewModel, isClearAll: Bool) {
        self.viewModel = viewModel
        self.isClearAll = isClearAll
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.showClearConfirmation = false
                        viewModel.showClearAllConfirmation = false
                    }
                }

            VStack(spacing: 12) {
                Image(systemName: isClearAll ? "trash.circle.fill" : "trash.circle")
                    .font(.system(size: 30))
                    .foregroundColor(.red)

                Text(isClearAll ? L10n(.clipboardClearAllConfirmMessage) : L10n(.clipboardClearConfirmMessage))
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                Toggle(isOn: Binding(
                    get: { viewModel.settings.suppressClearAlert },
                    set: { viewModel.settings.suppressClearAlert = $0 }
                )) {
                    Text(L10n(.clipboardClearDontAskAgain))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.showClearConfirmation = false
                            viewModel.showClearAllConfirmation = false
                        }
                    }) {
                        Text(L10n(.clipboardCancel))
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.showClearConfirmation = false
                            viewModel.showClearAllConfirmation = false
                        }
                        Task {
                            if isClearAll {
                                await viewModel.clearAll()
                            } else {
                                await viewModel.clearUnpinned()
                            }
                        }
                    }) {
                        Text(isClearAll ? L10n(.clipboardClearAllConfirm) : L10n(.clipboardClearConfirm))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .frame(width: 250)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
