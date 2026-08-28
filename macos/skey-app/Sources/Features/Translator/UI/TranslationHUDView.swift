import AppKit
import SwiftUI

// MARK: - TranslationHUDView

public struct TranslationHUDView: View {
    @ObservedObject var translatorSettings = AppSettings.shared.translator
    @ObservedObject var loc = LocalizationService.shared

    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLang: String = "auto"
    @State private var targetLang: String = "vi"
    @State private var isTranslating: Bool = false
    @State private var engineUsed: TranslationEngineType?
    @State private var latencyMs: Double = 0
    @State private var errorMessage: String?
    @State private var copyFeedback: Bool = false

    @FocusState private var isInputFocused: Bool

    public let initialText: String?
    public let onClose: () -> Void

    public init(initialText: String? = nil, onClose: @escaping () -> Void = {}) {
        self.initialText = initialText
        self.onClose = onClose
    }

    private var supportedLanguages: [(String, String)] {
        [
            ("vi", L10n("lang.vi")),
            ("en", L10n("lang.en")),
            ("ja", L10n("lang.ja")),
            ("zh", L10n("lang.zh")),
            ("ko", L10n("lang.ko")),
            ("fr", L10n("lang.fr")),
            ("de", L10n("lang.de"))
        ]
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Language Switcher & Swap
            headerBar

            Divider()

            // Main Content Area (Spacious & Scrollable)
            VStack(spacing: 12) {
                // Source Input Section
                sourceInputSection

                // Output Result Section (Scrollable)
                if isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.85)
                        Text(L10n("hud.translator.translating"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(8)
                } else if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if !translatedText.isEmpty {
                    translatedOutputSection
                }
            }
            .padding(14)

            Divider()

            // Bottom Action Bar
            bottomActionBar
        }
        .frame(width: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            self.isInputFocused = true
            if let initial = initialText, !initial.isEmpty {
                self.sourceText = initial
                self.performTranslation()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Close Button (macOS convention: controls on the left)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)

            // App Branding Icon & Title
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)

            Text(L10n("hud.translator.title"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            // Language Selector Bar
            HStack(spacing: 6) {
                // Source Language Picker
                Picker("", selection: $sourceLang) {
                    Text(L10n("hud.translator.auto")).tag("auto")
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 105)

                // Swap Languages Button
                Button {
                    swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(L10n("hud.translator.swapLangs"))

                // Target Language Picker
                Picker("", selection: $targetLang) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 115)
                .onChange(of: targetLang) { _, _ in
                    if !sourceText.isEmpty {
                        performTranslation()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Source Input Section (Scrollable & Clean)

    private var sourceInputSection: some View {
        VStack(spacing: 4) {
            // Text Area Container with vertical scroll
            ScrollView(.vertical) {
                TextField(L10n("hud.translator.placeholder"), text: $sourceText, axis: .vertical)
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 75, maxHeight: 130)
            .padding(10)
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isInputFocused ? Color.accentColor.opacity(0.6) : Color(NSColor.separatorColor).opacity(0.3),
                        lineWidth: isInputFocused ? 1.2 : 0.8
                    )
            )

            // Mini utility bar below input
            HStack(spacing: 8) {
                // Character counter
                if !sourceText.isEmpty {
                    Text("\(sourceText.count) \(L10n("hud.translator.chars"))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Paste button
                Button {
                    if let str = NSPasteboard.general.string(forType: .string), !str.isEmpty {
                        sourceText = str
                        performTranslation()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.clipboard")
                        Text(L10n("hud.translator.paste"))
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Clear button
                if !sourceText.isEmpty {
                    Button {
                        sourceText = ""
                        translatedText = ""
                        errorMessage = nil
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                            Text(L10n("hud.translator.clear"))
                        }
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }

    // MARK: - Translated Output Section (Scrollable & Clear Typography)

    private var translatedOutputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with Engine Badge & Copy Action
            HStack {
                if let engine = engineUsed {
                    HStack(spacing: 5) {
                        Image(systemName: engine.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(engine.displayName) • \(String(format: "%.0f", latencyMs))ms")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(engine.badgeColor.opacity(0.12))
                    .foregroundColor(engine.badgeColor)
                    .cornerRadius(4)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translatedText, forType: .string)
                    copyFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copyFeedback = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                        Text(copyFeedback ? L10n("hud.translator.copied") : L10n("hud.translator.copy"))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Scrollable Output Box
            ScrollView(.vertical) {
                Text(translatedText)
                    .font(.system(size: 13.5, weight: .regular))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 85, maxHeight: 150)
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.8)
            )
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack {
            Text(L10n("hud.translator.escHint"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                performTranslation()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(L10n("hud.translator.translateNow"))
                }
                .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func swapLanguages() {
        if sourceLang == "auto" {
            sourceLang = "vi"
            targetLang = "en"
        } else {
            let temp = sourceLang
            sourceLang = targetLang
            targetLang = temp
        }

        if !translatedText.isEmpty {
            let prevResult = translatedText
            sourceText = prevResult
            translatedText = ""
            performTranslation()
        }
    }

    private func performTranslation() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true
        errorMessage = nil

        Task {
            do {
                let res = try await TranslationService.shared.translate(
                    text: text,
                    from: sourceLang,
                    to: targetLang
                )
                await MainActor.run {
                    self.translatedText = res.translatedText
                    self.engineUsed = res.engineUsed
                    self.latencyMs = res.latencyMs
                    self.isTranslating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "\(L10n("hud.translator.error")) \(error.localizedDescription)"
                    self.isTranslating = false
                }
            }
        }
    }
}
