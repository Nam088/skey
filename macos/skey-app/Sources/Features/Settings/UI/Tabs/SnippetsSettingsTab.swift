import AppKit
import SwiftUI

// MARK: - Reusable Multiline Macro Text Area

public struct MacroTextArea: View {
    public let placeholder: String
    @Binding public var text: String
    public var minHeight: CGFloat

    public init(placeholder: String = "", text: Binding<String>, minHeight: CGFloat = 65) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(NSColor.placeholderTextColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 12.5))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(6)
                .frame(minHeight: minHeight)
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
        )
    }
}

// MARK: - SnippetsSettingsTab (Spacious Multiline Support)

public struct SnippetsSettingsTab: View {
    @ObservedObject var macroSettings = AppSettings.shared.macro
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    // Add state
    @State private var newShortcut: String = ""
    @State private var newReplacement: String = ""
    @State private var searchMacro: String = ""

    // Edit state
    @State private var editingItemID: UUID? = nil
    @State private var editShortcut: String = ""
    @State private var editReplacement: String = ""

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.snippetsList"), icon: "list.bullet.rectangle.portrait.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.backup"), icon: "arrow.up.doc.fill")
        ]
    }

    public init() {}

    private var filteredMacros: [MacroItem] {
        if searchMacro.trimmingCharacters(in: .whitespaces).isEmpty {
            return macroSettings.items
        }
        return macroSettings.items.filter {
            $0.shortcut.localizedCaseInsensitiveContains(searchMacro) ||
            $0.replacement.localizedCaseInsensitiveContains(searchMacro)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SubTabBar(items: subTabs, selectedTab: $navState.snippetsSubTab)

            ScrollView {
                VStack(spacing: 20) {
                    switch navState.snippetsSubTab {
                    case 0:
                        allInOneMacroSection
                    case 1:
                        backupSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 1. Tab 1: Cấu hình ở trên + Thêm mới (Text Area) + Bảng danh sách ở dưới

    private var allInOneMacroSection: some View {
        VStack(spacing: 18) {
            // 1.1 Cấu hình hoạt động (Nằm ở TRÊN CÙNG)
            SettingsGroup(title: L10n("macro.section.options")) {
                SettingsRow(
                    title: L10n("macro.option.enable"),
                    subtitle: L10n("macro.option.enableDesc"),
                    showDivider: macroSettings.isEnabled
                ) {
                    Toggle("", isOn: $macroSettings.isEnabled)
                        .toggleStyle(.switch)
                }

                if macroSettings.isEnabled {
                    SettingsRow(
                        title: L10n("macro.option.autoCaps"),
                        subtitle: L10n("macro.option.autoCapsDesc"),
                        showDivider: true
                    ) {
                        Toggle("", isOn: $macroSettings.autoCaps)
                            .toggleStyle(.switch)
                    }

                    SettingsRow(
                        title: L10n("macro.option.inEnglish"),
                        subtitle: L10n("macro.option.inEnglishDesc"),
                        showDivider: false
                    ) {
                        Toggle("", isOn: $macroSettings.inEnglishMode)
                            .toggleStyle(.switch)
                    }
                }
            }

            // 1.2 Khung Thêm từ gõ tắt mới (Spacious Text Area)
            SettingsGroup(title: L10n("macro.section.add")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField(L10n("macro.placeholder.shortcut"), text: $newShortcut)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .monospaced))
                            .frame(width: 160)

                        Spacer()

                        Button {
                            macroSettings.add(shortcut: newShortcut, replacement: newReplacement)
                            newShortcut = ""
                            newReplacement = ""
                        } label: {
                            Label(L10n("macro.action.add"), systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newShortcut.trimmingCharacters(in: .whitespaces).isEmpty || newReplacement.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    MacroTextArea(
                        placeholder: L10n("macro.placeholder.replacement"),
                        text: $newReplacement,
                        minHeight: 70
                    )
                }
                .padding(14)
            }

            // 1.3 Bảng danh sách từ gõ tắt (Nằm ở DƯỚI)
            SettingsGroup(title: "\(L10n("macro.section.list")) (\(macroSettings.items.count))") {
                VStack(spacing: 0) {
                    // Search in List
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField(L10n("macro.placeholder.search"), text: $searchMacro)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !searchMacro.isEmpty {
                            Button {
                                searchMacro = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.quaternaryLabelColor).opacity(0.12))

                    Divider()

                    if filteredMacros.isEmpty {
                        VStack(spacing: 8) {
                            Text(L10n("macro.status.empty"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(Array(filteredMacros.enumerated()), id: \.element.id) { index, item in
                            macroRow(item: item, index: index)

                            if index < filteredMacros.count - 1 {
                                Divider()
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func macroRow(item: MacroItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if editingItemID == item.id {
                // Editing mode (Spacious Text Area)
                HStack(spacing: 10) {
                    TextField("", text: $editShortcut)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 140)

                    Spacer()

                    Button(L10n("common.save")) {
                        macroSettings.add(shortcut: editShortcut, replacement: editReplacement)
                        editingItemID = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(L10n("common.cancel")) {
                        editingItemID = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                MacroTextArea(
                    placeholder: "",
                    text: $editReplacement,
                    minHeight: 65
                )
            } else {
                // Display mode
                HStack(alignment: .top, spacing: 12) {
                    KeyCapBadge(item.shortcut)
                        .frame(minWidth: 60, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    Text(item.replacement)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineSpacing(2.5)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Button {
                            editingItemID = item.id
                            editShortcut = item.shortcut
                            editReplacement = item.replacement
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(L10n("common.edit"))

                        Button {
                            macroSettings.remove(item: item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.borderless)
                        .help(L10n("common.delete"))
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 2. Sao lưu & Nhập / Xuất (Backup)

    private var backupSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("macro.section.backup")) {
                SettingsRow(
                    title: L10n("macro.option.export"),
                    subtitle: L10n("macro.option.exportDesc")
                ) {
                    Button(L10n("macro.action.exportBtn")) {
                        exportMacrosToFile()
                    }
                    .buttonStyle(.bordered)
                }

                SettingsRow(
                    title: L10n("macro.option.import"),
                    subtitle: L10n("macro.option.importDesc"),
                    showDivider: false
                ) {
                    Button(L10n("macro.action.importBtn")) {
                        importMacrosFromFile()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Import / Export Logic

    private func exportMacrosToFile() {
        let savePanel = NSSavePanel()
        savePanel.title = L10n("macro.option.export")
        savePanel.nameFieldStringValue = "skey_macros.txt"
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.plainText]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let content = macroSettings.items
                .map { "\($0.shortcut):\($0.replacement)" }
                .joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func importMacrosFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = L10n("macro.option.import")
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.plainText]

        if openPanel.runModal() == .OK, let url = openPanel.url,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    macroSettings.add(shortcut: parts[0], replacement: parts[1])
                }
            }
        }
    }
}
