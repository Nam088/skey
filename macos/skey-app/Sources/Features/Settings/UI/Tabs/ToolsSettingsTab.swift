import AppKit
import SwiftUI

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
        VStack(spacing: 16) {
            // Card 1: Lau màn hình & Vệ sinh phím
            SettingsGroup(title: L10n("cleaner.title")) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n("cleaner.title"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)

                            Text(L10n("cleaner.desc"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            KeyboardCleanerController.shared.startCleaning()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                Text(L10n("cleaner.action.start"))
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    Divider()

                    // Background Mode Previews
                    HStack(spacing: 8) {
                        Text(L10n("cleaner.section.modes"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        ForEach(CleanerBackgroundMode.allCases) { mode in
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 10))
                                Text(mode.title)
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.quaternaryLabelColor).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Card 2: Xử lý nhanh Clipboard
            SettingsGroup(title: L10n("tools.section.quickText")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n("tools.quickText.desc"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        quickActionButton(title: L10n("tools.action.tcvn3ToUnicode"), action: .tcvn3ToUnicode)
                        quickActionButton(title: L10n("tools.action.vniToUnicode"), action: .vniToUnicode)
                        quickActionButton(title: L10n("tools.action.unicodeToTcvn3"), action: .unicodeToTcvn3)
                        quickActionButton(title: L10n("tools.action.removeTones"), action: .removeTones)
                        quickActionButton(title: L10n("tools.action.toUppercase"), action: .toUppercase)
                        quickActionButton(title: L10n("tools.action.toLowercase"), action: .toLowercase)
                        quickActionButton(title: L10n("tools.action.toTitleCase"), action: .toTitleCase)
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

    private func quickActionButton(title: String, action: TextTransformService.QuickAction) -> some View {
        Button {
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
        } label: {
            HStack {
                Image(systemName: action.icon)
                    .font(.system(size: 11.5))
                    .foregroundColor(.indigo)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
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
        } else {
            targetText = sourceText
        }
    }
}
