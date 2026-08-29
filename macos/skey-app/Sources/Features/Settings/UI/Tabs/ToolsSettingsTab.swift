import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - EngineDropDelegate for Drag & Drop Reordering

struct EngineDropDelegate: DropDelegate {
    let item: TranslationEngineConfig
    let translatorSettings: TranslatorSettings
    @Binding var draggingItem: TranslationEngineConfig?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem, dragging.id != item.id else { return }
        let currentList = translatorSettings.engines
        guard let from = currentList.firstIndex(where: { $0.id == dragging.id }),
              let to = currentList.firstIndex(where: { $0.id == item.id }) else { return }

        if from != to {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                var updated = currentList
                updated.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                translatorSettings.engines = updated
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

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
    @ObservedObject var shortcutSettings = AppSettings.shared.shortcuts
    @ObservedObject var translatorSettings = AppSettings.shared.translator
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    // Converter State
    @State private var sourceFormat: String = "TCVN3"
    @State private var targetFormat: String = "Unicode"
    @State private var sourceText: String = ""
    @State private var targetText: String = ""
    @State private var isCopied: Bool = false
    @State private var quickActionFeedback: String? = nil

    // Translator Test State
    @State private var testInput: String = "Memory safety and low latency concurrency in SKey."
    @State private var testResult: String = ""
    @State private var testEngineUsed: String = ""
    @State private var testLatency: Double = 0
    @State private var isTestingTranslation: Bool = false
    @State private var testError: String? = nil
    @State private var draggingEngine: TranslationEngineConfig?

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.translator"), icon: "globe.asia.australia.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.utilities"), icon: "sparkles.rectangle.stack.fill"),
            SubTabItem(id: 2, title: L10n("settings.subtab.textConverter"), icon: "character.textbox")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubTabBar(items: subTabs, selectedTab: $navState.toolsSubTab)

            ScrollView {
                VStack(spacing: 14) {
                    switch navState.toolsSubTab {
                    case 0:
                        translatorSection
                    case 1:
                        utilitiesSection
                    case 2:
                        converterSection
                    default:
                        translatorSection
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.automatic)
        }
    }

    // MARK: - 0. Dịch nhanh (Translator with Priority Ordering)

    private var translatorSection: some View {
        VStack(spacing: 18) {
            // Card 1: Cài đặt phím tắt & ngôn ngữ
            SettingsGroup(title: L10n("tools.translator.title")) {
                SettingsRow(
                    title: L10n("tools.translator.shortcut"),
                    subtitle: L10n("tools.translator.shortcutDesc"),
                    showDivider: true
                ) {
                    HStack(spacing: 10) {
                        KeyCapBadge("⌥T")

                        Button(L10n("tools.translator.openHUD")) {
                            TranslationHUDController.shared.toggleHUD()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                SettingsRow(
                    title: L10n("tools.translator.targetLang"),
                    subtitle: L10n("tools.translator.targetLangDesc"),
                    showDivider: false
                ) {
                    Picker("", selection: $translatorSettings.targetLanguage) {
                        Text(L10n("lang.vi")).tag("vi")
                        Text(L10n("lang.en")).tag("en")
                        Text(L10n("lang.ja")).tag("ja")
                        Text(L10n("lang.zh")).tag("zh")
                        Text(L10n("lang.ko")).tag("ko")
                        Text(L10n("lang.fr")).tag("fr")
                        Text(L10n("lang.de")).tag("de")
                    }
                    .frame(width: 150)
                }
            }

            // Card 2: Thứ tự ưu tiên Nguồn dịch (Priority Reordering)
            SettingsGroup(title: L10n("tools.translator.priorityTitle")) {
                VStack(spacing: 0) {
                    ForEach(Array(translatorSettings.engines.enumerated()), id: \.element.id) { index, engine in
                        enginePriorityRow(index: index, engine: engine)

                        if index < translatorSettings.engines.count - 1 {
                            Divider()
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }

            // Card 3: Thử nghiệm Dịch trực tiếp
            SettingsGroup(title: L10n("tools.translator.testTitle")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField(L10n("tools.translator.testInputPlaceholder"), text: $testInput)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            runTestTranslation()
                        } label: {
                            HStack(spacing: 4) {
                                if isTestingTranslation {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(L10n("tools.translator.testBtn"))
                            }
                            .font(.system(size: 11.5, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isTestingTranslation || testInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let err = testError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }

                    if !testResult.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n("tools.translator.testOutput"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Spacer()

                                if !testEngineUsed.isEmpty {
                                    Text("\(testEngineUsed) • \(String(format: "%.0f", testLatency))ms")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }

                            Text(testResult)
                                .font(.system(size: 12.5))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Engine Row Component

    @ViewBuilder
    private func enginePriorityRow(index: Int, engine: TranslationEngineConfig) -> some View {
        let isDragging = draggingEngine?.id == engine.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Drag / Reorder Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 14)

                // Priority Badge
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                    .clipShape(Circle())

                // Engine Icon
                Image(systemName: engine.type.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(engine.type.badgeColor)
                    .frame(width: 28, height: 28)
                    .background(engine.type.badgeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 6) {
                        Text(engine.type.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        if engine.type.isFreeNoKeyRequired {
                            Text(L10n("tools.translator.freeBadge"))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    Text(engine.type.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                // Subtle Up/Down buttons
                HStack(spacing: 2) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            translatorSettings.moveEngineUp(at: index)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(index == 0 ? .secondary.opacity(0.3) : .secondary)
                    .disabled(index == 0)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            translatorSettings.moveEngineDown(at: index)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(index == translatorSettings.engines.count - 1 ? .secondary.opacity(0.3) : .secondary)
                    .disabled(index == translatorSettings.engines.count - 1)
                }

                // Enable Toggle
                Toggle("", isOn: Binding(
                    get: { engine.isEnabled },
                    set: { translatorSettings.toggleEngine(for: engine.type, isEnabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // API Key Input for Non-free engines
            if !engine.type.isFreeNoKeyRequired {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)

                    SecureField(L10n("tools.translator.apiKeyPlaceholder"), text: Binding(
                        get: { engine.apiKey },
                        set: { translatorSettings.updateApiKey(for: engine.type, key: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .controlSize(.small)
                }
                .padding(.leading, 62)
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDragging ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .onDrag {
            self.draggingEngine = engine
            return NSItemProvider(object: engine.id as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: EngineDropDelegate(
                item: engine,
                translatorSettings: translatorSettings,
                draggingItem: $draggingEngine
            )
        )
    }

    private func runTestTranslation() {
        let text = testInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTestingTranslation = true
        testError = nil

        Task {
            do {
                let res = try await TranslationService.shared.translate(
                    text: text,
                    to: translatorSettings.targetLanguage
                )
                await MainActor.run {
                    self.testResult = res.translatedText
                    self.testEngineUsed = res.engineUsed.displayName
                    self.testLatency = res.latencyMs
                    self.isTestingTranslation = false
                }
            } catch {
                await MainActor.run {
                    self.testError = "\(L10n("tools.translator.errorPrefix")) \(error.localizedDescription)"
                    self.isTestingTranslation = false
                }
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

                    // Source Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n("tools.converter.input"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        MacroTextArea(
                            placeholder: L10n("tools.converter.placeholder"),
                            text: $sourceText,
                            minHeight: 75
                        )
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
