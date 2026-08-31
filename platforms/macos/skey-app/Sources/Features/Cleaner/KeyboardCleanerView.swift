import AppKit
import SwiftUI

// MARK: - KeyboardCleanerView (Dynamic Island Floating HUD Capsule)

public struct KeyboardCleanerView: View {
    @ObservedObject var controller: KeyboardCleanerController
    @ObservedObject var loc = LocalizationService.shared
    @State private var isCompact = false

    public init(controller: KeyboardCleanerController) {
        self.controller = controller
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Drag Handle Indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
                .help(L10n("cleaner.help.drag"))

            // Lock Badge
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)

                if !isCompact {
                    Text(L10n("cleaner.badge.locked"))
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color.orange)
            )

            // Esc Hold Indicator
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 2.5)
                        .frame(width: 22, height: 22)

                    Circle()
                        .trim(from: 0, to: controller.unlockProgress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.05), value: controller.unlockProgress)

                    Text("Esc")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(controller.isHoldingEsc ? .green : .primary)
                }

                Text(controller.isHoldingEsc ? L10n("cleaner.esc.holding") : L10n("cleaner.esc.hint"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(controller.isHoldingEsc ? .green : .primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
            )

            if !isCompact {
                // Background Mode Picker Menu
                Menu {
                    ForEach(CleanerBackgroundMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                controller.setBackgroundMode(mode)
                            }
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.title)
                                if controller.backgroundMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: controller.backgroundMode.icon)
                            .font(.system(size: 10))
                        Text(controller.backgroundMode.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Unlock Button
            Button {
                controller.unlockAndClose()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(L10n("cleaner.button.unlock"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
            }
            .buttonStyle(.plain)

            // Compact / Expand Toggle Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isCompact.toggle()
                }
            } label: {
                Image(systemName: isCompact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help(isCompact ? L10n("cleaner.help.expand") : L10n("cleaner.help.collapse"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.8)
        )
        .fixedSize()
    }
}

// MARK: - VisualEffectBlurView Helper

public struct VisualEffectBlurView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
