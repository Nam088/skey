import AppKit
import SwiftUI

// MARK: - QuickActionButton Component (With Smooth Hover Effect)

public struct QuickActionButton: View {
    public let title: String
    public let icon: String
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.indigo.opacity(isHovered ? 0.18 : 0.10))
                        .frame(width: 26, height: 26)

                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.indigo)
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(isHovered ? 0.8 : 0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.95 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isHovered ? Color.indigo.opacity(0.35) : Color(NSColor.separatorColor).opacity(0.3),
                        lineWidth: isHovered ? 0.8 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - ToolsSettingsTab

public struct ToolsSettingsTab: View {
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    // Converter State
    @State private var sourceFormat: String = "TCVN3"
    @State private var targetFormat: String = "Unicode"
    @State private var sourceText: String = ""
    @State private var targetText: String = ""
    @State private var isCopied: Bool = false
    @State private var quickActionFeedback: String? = nil

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.utilities"), icon: "sparkles.rectangle.stack.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.textConverter"), icon: "character.textbox")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SubTabBar(items: subTabs, selectedTab: $navState.toolsSubTab)

            ScrollView {
                VStack(spacing: 20) {
                    switch navState.toolsSubTab {
                    case 0:
                        utilitiesSection
                    case 1:
                        converterSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 1. Tiện ích & Vệ sinh (Utilities & Cleaner)

    private var utilitiesSection: some View {
        VStack(spacing: 18) {
            // Card 1: Lau màn hình & Vệ sinh phím
            SettingsGroup(title: L10n("cleaner.title")) {
                SettingsRow(
                    title: L10n("cleaner.title"),
                    subtitle: L10n("cleaner.desc"),
                    showDivider: false
                ) {
                    Button {
                        KeyboardCleanerController.shared.startCleaning()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                            Text(L10n("cleaner.action.start"))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }

            // Card 2: Xử lý nhanh Clipboard & Chuyển mã
            SettingsGroup(title: L10n("tools.section.quickText")) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n("tools.quickText.desc"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    // Subsection 1: Chuyển đổi bảng mã (2x2 Grid)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n("tools.quick.encodingHeader"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                            quickButton(title: L10n("tools.action.tcvn3ToUnicode"), action: .tcvn3ToUnicode)
                            quickButton(title: L10n("tools.action.unicodeToTcvn3"), action: .unicodeToTcvn3)
                            quickButton(title: L10n("tools.action.vniToUnicode"), action: .vniToUnicode)
                            quickButton(title: L10n("tools.action.unicodeToVni"), action: .unicodeToVni)
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)

                    // Subsection 2: Kiểu chữ & Dấu (2x2 Grid)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n("tools.quick.caseHeader"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                            quickButton(title: L10n("tools.action.toUppercase"), action: .toUppercase)
                            quickButton(title: L10n("tools.action.toLowercase"), action: .toLowercase)
                            quickButton(title: L10n("tools.action.toTitleCase"), action: .toTitleCase)
                            quickButton(title: L10n("tools.action.removeTones"), action: .removeTones)
                        }
                    }

                    if let feedback = quickActionFeedback {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feedback)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func quickButton(title: String, action: TextTransformService.QuickAction) -> some View {
        QuickActionButton(title: title, icon: action.icon) {
            let success = TextTransformService.shared.transformClipboard(action: action)
            if success {
                withAnimation {
                    quickActionFeedback = L10n("tools.quickText.success")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        quickActionFeedback = nil
                    }
                }
            }
        }
    }

    // MARK: - 2. Chuyển mã văn bản (Text & Code Table Converter)

    private var converterSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("tools.section.converter")) {
                VStack(alignment: .leading, spacing: 14) {
                    // Selector Row
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n("tools.converter.source"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Picker("", selection: $sourceFormat) {
                                Text("TCVN3 (ABC)").tag("TCVN3")
                                Text("VNI Windows").tag("VNI")
                                Text("Unicode").tag("Unicode")
                            }
                            .frame(width: 140)
                            .labelsHidden()
                        }

                        Button {
                            swapFormats()
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.indigo)
                                .padding(8)
                                .background(Color(NSColor.quaternaryLabelColor).opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n("tools.converter.target"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Picker("", selection: $targetFormat) {
                                Text("Unicode").tag("Unicode")
                                Text("TCVN3 (ABC)").tag("TCVN3")
                                Text("VNI Windows").tag("VNI")
                            }
                            .frame(width: 140)
                            .labelsHidden()
                        }

                        Spacer()
                    }

                    Divider()

                    // Source Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n("tools.converter.input"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Button {
                                if let clip = NSPasteboard.general.string(forType: .string) {
                                    sourceText = clip
                                    performConvert()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text(L10n("tools.converter.paste"))
                                }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }

                        MacroTextArea(
                            placeholder: L10n("tools.converter.placeholder"),
                            text: $sourceText,
                            minHeight: 75
                        )
                        .onChange(of: sourceText) { _, _ in
                            performConvert()
                        }
                    }

                    // Convert Buttons
                    HStack {
                        Button {
                            performConvert()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(L10n("tools.converter.convert"))
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)

                        if !targetText.isEmpty {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(targetText, forType: .string)
                                isCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    isCopied = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    Text(isCopied ? L10n("tools.converter.copied") : L10n("tools.converter.copy"))
                                }
                                .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                    }

                    // Converted Output
                    if !targetText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n("tools.converter.output"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            MacroTextArea(
                                placeholder: "",
                                text: .constant(targetText),
                                minHeight: 75
                            )
                        }
                    }
                }
            }
        }
    }

    private func swapFormats() {
        let temp = sourceFormat
        sourceFormat = targetFormat
        targetFormat = temp
        if !targetText.isEmpty {
            sourceText = targetText
            performConvert()
        }
    }

    private func performConvert() {
        guard !sourceText.isEmpty else {
            targetText = ""
            return
        }

        if sourceFormat == "TCVN3" && targetFormat == "Unicode" {
            targetText = TextTransformService.shared.tcvn3ToUnicode(sourceText)
        } else if sourceFormat == "Unicode" && targetFormat == "TCVN3" {
            targetText = TextTransformService.shared.unicodeToTcvn3(sourceText)
        } else if sourceFormat == "VNI" && targetFormat == "Unicode" {
            targetText = TextTransformService.shared.vniToUnicode(sourceText)
        } else if sourceFormat == "Unicode" && targetFormat == "VNI" {
            targetText = TextTransformService.shared.unicodeToVni(sourceText)
        } else {
            targetText = sourceText
        }
    }
}
