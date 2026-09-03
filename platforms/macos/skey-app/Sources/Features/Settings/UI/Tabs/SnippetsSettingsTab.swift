import AppKit
import SwiftUI

// MARK: - Reusable Multiline Macro Text Area

public struct MacroTextArea: View {
    public let placeholder: String
    @Binding public var text: String
    public var minHeight: CGFloat

    public init(placeholder: String = "", text: Binding<String>, minHeight: CGFloat = 80) {
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
        )
    }
}

// MARK: - FlowLayout (Responsive Wrapping Multi-row Chips)

public struct FlowLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 6, verticalSpacing: CGFloat = 6) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentLineWidth + size.width > maxWidth, currentLineWidth > 0 {
                totalHeight += currentLineHeight + verticalSpacing
                currentLineWidth = size.width + horizontalSpacing
                currentLineHeight = size.height
            } else {
                currentLineWidth += size.width + horizontalSpacing
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }
        totalHeight += currentLineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += currentLineHeight + verticalSpacing
                currentLineHeight = size.height
            } else {
                currentLineHeight = max(currentLineHeight, size.height)
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + horizontalSpacing
        }
    }
}

// MARK: - Macro Filter Enum

public enum MacroFilter: String, CaseIterable, Identifiable {
    case all
    case dynamic
    case constants

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:       return L10n("macro.filter.all")
        case .dynamic:   return L10n("macro.filter.dynamic")
        case .constants: return L10n("macro.filter.constants")
        }
    }

    public var icon: String {
        switch self {
        case .all:       return "line.3.horizontal.decrease.circle"
        case .dynamic:   return "bolt.fill"
        case .constants: return "character.textbox"
        }
    }
}

// MARK: - SnippetsSettingsTab

public struct SnippetsSettingsTab: View {
    @ObservedObject var macroSettings = AppSettings.shared.macro
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    // MARK: - Macro List State
    @State private var searchMacro: String = ""
    @State private var selectedFilter: MacroFilter = .all
    @State private var hoveredSnippetID: UUID? = nil
    @State private var copiedSnippetID: UUID? = nil
    @State private var editingSnippet: MacroItem? = nil
    @State private var isCreatingNewSnippet: Bool = false

    // Quick Tester State
    @State private var quickTestText: String = ""
    @State private var quickTestMatchedExpansion: String? = nil

    // MARK: - Constants List State
    @State private var searchConstant: String = ""
    @State private var hoveredConstantID: UUID? = nil
    @State private var copiedConstantID: UUID? = nil
    @State private var copiedConstantType: String? = nil // "token" or "value"
    @State private var editingConstant: MacroConstant? = nil
    @State private var isCreatingNewConstant: Bool = false
    @State private var customPrefixInput: String = ""

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.snippetsList"), icon: "list.bullet.rectangle.portrait.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.constants"), icon: "character.textbox"),
            SubTabItem(id: 2, title: L10n("settings.subtab.options"), icon: "gearshape.fill"),
            SubTabItem(id: 3, title: L10n("settings.subtab.backup"), icon: "arrow.up.doc.fill")
        ]
    }

    public init() {}

    private var filteredMacros: [MacroItem] {
        var list = macroSettings.items
        let query = searchMacro.trimmingCharacters(in: .whitespaces)

        if !query.isEmpty {
            list = list.filter {
                $0.shortcut.localizedCaseInsensitiveContains(query) ||
                $0.replacement.localizedCaseInsensitiveContains(query)
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .dynamic:
            list = list.filter { hasDynamicVariables($0.replacement) }
        case .constants:
            list = list.filter { $0.replacement.contains("{$") }
        }

        return list
    }

    private var filteredConstants: [MacroConstant] {
        let query = searchConstant.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return macroSettings.constants
        }
        return macroSettings.constants.filter {
            $0.key.localizedCaseInsensitiveContains(query) ||
            $0.value.localizedCaseInsensitiveContains(query)
        }
    }

    private var dynamicMacrosCount: Int {
        macroSettings.items.filter { hasDynamicVariables($0.replacement) }.count
    }

    private var constantsMacrosCount: Int {
        macroSettings.items.filter { $0.replacement.contains("{$") }.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SubTabBar(items: subTabs, selectedTab: $navState.snippetsSubTab)

            VStack(spacing: 14) {
                switch navState.snippetsSubTab {
                case 0:
                    modernMacroManagementSection
                case 1:
                    modernConstantsSection
                case 2:
                    optionsSection
                case 3:
                    backupSection
                default:
                    EmptyView()
                }
            }
            .padding(.top, 2)
        }
        // Sheets for Add/Edit
        .sheet(item: $editingSnippet) { item in
            SnippetEditorSheet(
                existingSnippet: item,
                onSave: { shortcut, replacement in
                    if let index = macroSettings.items.firstIndex(where: { $0.id == item.id }) {
                        macroSettings.items[index].shortcut = shortcut
                        macroSettings.items[index].replacement = replacement
                        macroSettings.saveItems()
                    }
                    editingSnippet = nil
                },
                onCancel: {
                    editingSnippet = nil
                }
            )
        }
        .sheet(isPresented: $isCreatingNewSnippet) {
            SnippetEditorSheet(
                existingSnippet: nil,
                onSave: { shortcut, replacement in
                    macroSettings.add(shortcut: shortcut, replacement: replacement)
                    isCreatingNewSnippet = false
                },
                onCancel: {
                    isCreatingNewSnippet = false
                }
            )
        }
        .sheet(item: $editingConstant) { item in
            ConstantEditorSheet(
                existingConstant: item,
                onSave: { key, value in
                    if let index = macroSettings.constants.firstIndex(where: { $0.id == item.id }) {
                        macroSettings.constants[index].key = key
                        macroSettings.constants[index].value = value
                        macroSettings.saveConstants()
                    }
                    editingConstant = nil
                },
                onCancel: {
                    editingConstant = nil
                }
            )
        }
        .sheet(isPresented: $isCreatingNewConstant) {
            ConstantEditorSheet(
                existingConstant: nil,
                onSave: { key, value in
                    macroSettings.addConstant(key: key, value: value)
                    isCreatingNewConstant = false
                },
                onCancel: {
                    isCreatingNewConstant = false
                }
            )
        }
        .onAppear {
            customPrefixInput = macroSettings.constantPrefix
        }
    }

    // MARK: - 1. Tab 1: Modern Macro Management Section

    private var modernMacroManagementSection: some View {
        VStack(spacing: 12) {
            // Disabled Warning Banner (if disabled)
            if !macroSettings.isEnabled {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))

                    Text(L10n("macro.status.disabled"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(L10n("macro.action.enableNow")) {
                        macroSettings.isEnabled = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Controls Row 1: Search Field + Add Button
            HStack(spacing: 10) {
                // Search Input Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
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
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                )

                // Primary Add Button
                Button {
                    isCreatingNewSnippet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text(L10n("macro.action.add"))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            // Controls Row 2: Filter Capsule Tabs + Count
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    filterTabButton(.all, count: macroSettings.items.count)
                    filterTabButton(.dynamic, count: dynamicMacrosCount)
                    filterTabButton(.constants, count: constantsMacrosCount)
                }
                .padding(2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Spacer()

                let totalSuffix = filteredMacros.count != macroSettings.items.count ? String(format: L10n("macro.table.ofTotal"), macroSettings.items.count) : ""
                Text("\(filteredMacros.count) \(L10n("macro.unit.items"))\(totalSuffix)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Main Snippets Table Card
            VStack(spacing: 0) {
                // Table Column Headers
                HStack(spacing: 12) {
                    Text(L10n("macro.table.shortcut"))
                        .frame(width: 100, alignment: .leading)

                    Text(L10n("macro.table.replacement"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(L10n("macro.table.actions"))
                        .frame(width: 85, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.75))

                Divider()

                // Table Rows List
                if filteredMacros.isEmpty {
                    emptySnippetListView
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 5) {
                        ForEach(filteredMacros) { item in
                            macroRowView(item: item)
                        }
                    }
                    .padding(8)
                }

                Divider()

                // Table Footer Bar
                HStack {
                    Text(L10n("macro.table.doubleClickHint"))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.8))

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )

            // Quick Live Macro Tester Bar
            quickMacroTesterView
        }
    }

    private func filterTabButton(_ filter: MacroFilter, count: Int) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.18))
                    .clipShape(Capsule())
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func macroRowView(item: MacroItem) -> some View {
        let isHovered = hoveredSnippetID == item.id
        let isCopied = copiedSnippetID == item.id
        let lineCount = item.replacement.components(separatedBy: .newlines).count

        return HStack(spacing: 12) {
            // 1. Shortcut Badge (Keycap Style)
            HStack(spacing: 4) {
                Text(item.shortcut)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlColor).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.7), lineWidth: 0.75)
            )
            .frame(width: 100, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))

            // 2. Replacement Preview & Metadata Badges
            VStack(alignment: .leading, spacing: 3) {
                Text(item.replacement.replacingOccurrences(of: "\n", with: " ↵ "))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if lineCount > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 8))
                            Text(String(format: L10n("macro.table.lineCount"), lineCount))
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                        .clipShape(Capsule())
                    }

                    if hasDynamicVariables(item.replacement) {
                        HStack(spacing: 2.5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7.5))
                            Text(L10n("macro.filter.dynamic"))
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    if item.replacement.contains("{$") {
                        HStack(spacing: 2.5) {
                            Image(systemName: "character.textbox")
                                .font(.system(size: 7.5))
                            Text(L10n("macro.filter.constants"))
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Action Buttons
            HStack(spacing: 4) {
                // Copy Button
                Button {
                    copyToClipboard(item.replacement)
                    copiedSnippetID = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if copiedSnippetID == item.id {
                            copiedSnippetID = nil
                        }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(isCopied ? .green : .secondary)
                        .frame(width: 25, height: 25)
                        .background(isCopied ? Color.green.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.action.copy"))

                // Edit Button
                Button {
                    editingSnippet = item
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11.5))
                        .foregroundColor(.accentColor)
                        .frame(width: 25, height: 25)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.editor.editTitle"))

                // Delete Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        macroSettings.remove(item: item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 25, height: 25)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.action.deleteHelp"))
            }
            .frame(width: 85, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.95) : Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color(NSColor.separatorColor).opacity(0.2), lineWidth: 0.5)
        )
        .onHover { isHov in
            hoveredSnippetID = isHov ? item.id : nil
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingSnippet = item
        }
    }

    private var emptySnippetListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchMacro.isEmpty ? L10n("macro.status.empty") : L10n("macro.table.searchEmpty"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(searchMacro.isEmpty ? L10n("macro.table.emptyDesc") : L10n("macro.table.searchEmptyDesc"))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if searchMacro.isEmpty {
                Button {
                    isCreatingNewSnippet = true
                } label: {
                    Label(L10n("macro.action.add"), systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 30)
    }

    // Quick Live Macro Tester Bar
    private var quickMacroTesterView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 26, height: 26)

                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n("macro.test.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                TextField(L10n("macro.test.placeholder"), text: $quickTestText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: quickTestText) { _, newValue in
                        evaluateQuickTest(newValue)
                    }
            }

            if let result = quickTestMatchedExpansion {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundColor(.green)

                    Text(result)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .transition(.scale.combined(with: .opacity))
            } else if !quickTestText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(L10n("macro.test.nomatch"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            if !quickTestText.isEmpty {
                Button {
                    quickTestText = ""
                    quickTestMatchedExpansion = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private func evaluateQuickTest(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            quickTestMatchedExpansion = nil
            return
        }

        if let matched = MacroEngine.shared.testExpand(shortcut: trimmed) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                quickTestMatchedExpansion = matched
            }
        } else {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                quickTestMatchedExpansion = nil
            }
        }
    }

    // MARK: - 2. Tab 2: Modern Constants Management Section

    private var modernConstantsSection: some View {
        VStack(spacing: 12) {
            // Visual Explainer Banner
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "character.textbox")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n("macro.constant.infoTitle"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(L10n("macro.constant.infoDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.green.opacity(0.25), lineWidth: 0.5)
            )

            // Direct Typing Prefix Config Bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(macroSettings.directConstantsEnabled ? .green : .secondary)

                    Text(L10n("macro.constant.directPrefixBar"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }

                if macroSettings.directConstantsEnabled {
                    Menu {
                        Section {
                            ForEach([":", "$", ";", "@", "."], id: \.self) { p in
                                Button {
                                    macroSettings.constantPrefix = p
                                    customPrefixInput = p
                                } label: {
                                    HStack {
                                        Text("\(p)   (vd: \(p)email)")
                                        if macroSettings.constantPrefix == p {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(macroSettings.constantPrefix)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    TextField("prefix", text: $customPrefixInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 28)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                        )
                        .onChange(of: customPrefixInput) { _, newVal in
                            let trimmed = newVal.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                macroSettings.constantPrefix = trimmed
                            }
                        }

                    Text(String(format: L10n("macro.constant.directPrefixDesc"), macroSettings.constantPrefix))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $macroSettings.directConstantsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
            )

            // Top Controls Bar: Search + Add Button
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                    TextField(L10n("macro.constant.searchPlaceholder"), text: $searchConstant)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchConstant.isEmpty {
                        Button {
                            searchConstant = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                )

                Spacer()

                // Primary Add Constant Button
                Button {
                    isCreatingNewConstant = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12.5))
                        Text(L10n("macro.constant.addBtn"))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
            }

            // Main Constants Table Card
            VStack(spacing: 0) {
                // Table Headers
                HStack(spacing: 12) {
                    Text(L10n("macro.constant.table.key"))
                        .frame(width: 120, alignment: .leading)

                    Text(L10n("macro.constant.table.value"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(L10n("macro.table.actions"))
                        .frame(width: 125, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.75))

                Divider()

                // Table Rows List
                if filteredConstants.isEmpty {
                    emptyConstantListView
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 5) {
                        ForEach(filteredConstants) { item in
                            constantRowView(item: item)
                        }
                    }
                    .padding(8)
                }

                Divider()

                // Table Footer Bar
                HStack {
                    Text("\(filteredConstants.count) \(L10n("macro.constant.unit"))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(L10n("macro.table.doubleClickHint"))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    private func constantRowView(item: MacroConstant) -> some View {
        let isHovered = hoveredConstantID == item.id
        let isTokenCopied = copiedConstantID == item.id && copiedConstantType == "token"
        let isValueCopied = copiedConstantID == item.id && copiedConstantType == "value"

        return HStack(spacing: 12) {
            // 1. Token Pill Badge & Direct Typing Tag
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(item.token)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.green.opacity(0.35), lineWidth: 0.75)
                )

                if macroSettings.directConstantsEnabled && !macroSettings.constantPrefix.isEmpty {
                    Text("\(macroSettings.constantPrefix)\(item.key)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .frame(width: 120, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))

            // 2. Value Text Preview
            Text(item.value.replacingOccurrences(of: "\n", with: " ↵ "))
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Action Buttons
            HStack(spacing: 4) {
                // Copy Token Button
                Button {
                    copyToClipboard(item.token)
                    copiedConstantID = item.id
                    copiedConstantType = "token"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if copiedConstantID == item.id && copiedConstantType == "token" {
                            copiedConstantID = nil
                            copiedConstantType = nil
                        }
                    }
                } label: {
                    Image(systemName: isTokenCopied ? "checkmark" : "tag.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        .frame(width: 25, height: 25)
                        .background(isTokenCopied ? Color.green.opacity(0.25) : Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(String(format: L10n("macro.constant.copyTokenHelp"), item.token))

                // Copy Value Button
                Button {
                    copyToClipboard(item.value)
                    copiedConstantID = item.id
                    copiedConstantType = "value"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if copiedConstantID == item.id && copiedConstantType == "value" {
                            copiedConstantID = nil
                            copiedConstantType = nil
                        }
                    }
                } label: {
                    Image(systemName: isValueCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(isValueCopied ? .green : .secondary)
                        .frame(width: 25, height: 25)
                        .background(isValueCopied ? Color.green.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.constant.copyValue"))

                // Edit Button
                Button {
                    editingConstant = item
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11.5))
                        .foregroundColor(.green)
                        .frame(width: 25, height: 25)
                        .background(Color.green.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.constant.editTitle"))

                // Delete Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        macroSettings.removeConstant(item: item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 25, height: 25)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n("macro.constant.deleteHelp"))
            }
            .frame(width: 125, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.95) : Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isHovered ? Color.green.opacity(0.35) : Color(NSColor.separatorColor).opacity(0.2), lineWidth: 0.5)
        )
        .onHover { isHov in
            hoveredConstantID = isHov ? item.id : nil
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingConstant = item
        }
    }

    private var emptyConstantListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.textbox")
                .font(.system(size: 32))
                .foregroundColor(.green.opacity(0.5))

            Text(searchConstant.isEmpty ? L10n("macro.constant.empty") : L10n("macro.constant.searchEmpty"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(searchConstant.isEmpty ? L10n("macro.constant.emptyDescGeneral") : L10n("macro.constant.searchEmptyDesc"))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if searchConstant.isEmpty {
                Button {
                    isCreatingNewConstant = true
                } label: {
                    Label(L10n("macro.constant.addBtn"), systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 30)
    }

    // MARK: - 3. Tab 3: Options

    private var optionsSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("macro.section.options")) {
                SettingsRow(
                    title: L10n("macro.option.enable"),
                    subtitle: L10n("macro.option.enableDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: $macroSettings.isEnabled)
                        .toggleStyle(.switch)
                }

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
                    showDivider: true
                ) {
                    Toggle("", isOn: $macroSettings.inEnglishMode)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("macro.option.dynamicVariables"),
                    subtitle: L10n("macro.option.dynamicVariablesDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: $macroSettings.dynamicVariablesEnabled)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("macro.option.directConstants"),
                    subtitle: L10n("macro.option.directConstantsDesc"),
                    showDivider: macroSettings.directConstantsEnabled
                ) {
                    Toggle("", isOn: $macroSettings.directConstantsEnabled)
                        .toggleStyle(.switch)
                }

                if macroSettings.directConstantsEnabled {
                    SettingsRow(
                        title: L10n("macro.option.constantPrefix"),
                        subtitle: L10n("macro.option.constantPrefixDesc"),
                        showDivider: false
                    ) {
                        Picker("", selection: $macroSettings.constantPrefix) {
                            Text(":  (Hai chấm)").tag(":")
                            Text("$  (Đô la)").tag("$")
                            Text(";  (Chấm phẩy)").tag(";")
                            Text("@  (A còng)").tag("@")
                            Text(".  (Dấu chấm)").tag(".")
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
    }

    // MARK: - 4. Tab 4: Backup

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

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func hasDynamicVariables(_ text: String) -> Bool {
        text.contains("{date}") || text.contains("{time}") || text.contains("{datetime}") ||
        text.contains("{year}") || text.contains("{month}") || text.contains("{day}") ||
        text.contains("{weekday}") || text.contains("{timestamp}") || text.contains("{uuid}") ||
        text.contains("{guid}") || text.contains("{clipboard}")
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

// MARK: - SnippetEditorSheet (Spacious & Friendly Add/Edit Dialog)

public struct SnippetEditorSheet: View {
    public let existingSnippet: MacroItem?
    public let onSave: (String, String) -> Void
    public let onCancel: () -> Void

    @State private var shortcut: String = ""
    @State private var replacement: String = ""
    @State private var selectedChipCategory: Int = 0
    @ObservedObject var macroSettings = AppSettings.shared.macro

    public init(
        existingSnippet: MacroItem?,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingSnippet = existingSnippet
        self.onSave = onSave
        self.onCancel = onCancel
        _shortcut = State(initialValue: existingSnippet?.shortcut ?? "")
        _replacement = State(initialValue: existingSnippet?.replacement ?? "")
    }

    private var isDuplicateShortcut: Bool {
        let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        return macroSettings.items.contains {
            $0.shortcut.lowercased() == trimmed && $0.id != existingSnippet?.id
        }
    }

    private var livePreviewText: String {
        MacroEngine.shared.previewExpansion(for: replacement)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.gradient)
                        .frame(width: 34, height: 34)

                    Image(systemName: existingSnippet != nil ? "pencil" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(existingSnippet != nil ? L10n("macro.editor.editTitle") : L10n("macro.editor.createTitle"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    Text(L10n("macro.editor.subtitle"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Phím tắt (Shortcut)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(L10n("macro.placeholder.shortcut"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            if isDuplicateShortcut {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                    Text(L10n("macro.editor.duplicateWarning"))
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .foregroundColor(.orange)
                            }
                        }

                        TextField(L10n("macro.placeholder.shortcutExample"), text: $shortcut)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }

                    // 2. Nội dung mở rộng (Replacement)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(L10n("macro.placeholder.replacement"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            let lines = replacement.components(separatedBy: .newlines).count
                            Text(String(format: L10n("macro.editor.counter"), replacement.count, lines))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }

                        MacroTextArea(
                            placeholder: L10n("macro.placeholder.replacementExample"),
                            text: $replacement,
                            minHeight: 110
                        )
                    }

                    // 3. Quick Insert Variables & Constants Library
                    if macroSettings.dynamicVariablesEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                Text(L10n("macro.editor.insertVars"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Spacer()

                                // Category Picker
                                Picker("", selection: $selectedChipCategory) {
                                    Text(L10n("macro.editor.category.time")).tag(0)
                                    Text(L10n("macro.editor.category.system")).tag(1)
                                    Text(L10n("macro.editor.category.constants") + " (\(macroSettings.constants.count))").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 250)
                            }

                            if selectedChipCategory == 0 {
                                FlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
                                    timeVariableChip("{date}", desc: L10n("macro.var.date"))
                                    timeVariableChip("{time}", desc: L10n("macro.var.time"))
                                    timeVariableChip("{datetime}", desc: L10n("macro.var.datetime"))
                                    timeVariableChip("{weekday}", desc: L10n("macro.var.weekday"))
                                    timeVariableChip("{timestamp}", desc: L10n("macro.var.timestamp"))
                                    timeVariableChip("{year}", desc: L10n("macro.var.year"))
                                    timeVariableChip("{month}", desc: L10n("macro.var.month"))
                                    timeVariableChip("{day}", desc: L10n("macro.var.day"))
                                }
                            } else if selectedChipCategory == 1 {
                                FlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
                                    systemVariableChip("{clipboard}", desc: L10n("macro.var.clipboard"))
                                    systemVariableChip("{uuid}", desc: L10n("macro.var.uuid"))
                                }
                            } else {
                                if macroSettings.constants.isEmpty {
                                    Text(L10n("macro.editor.noConstants"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 4)
                                } else {
                                    FlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
                                        ForEach(macroSettings.constants) { c in
                                            constantVariableChip(c.token, desc: c.value)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    // 4. Live Expansion Preview Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            Text(L10n("macro.editor.livePreview"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(livePreviewText.isEmpty ? L10n("macro.editor.previewEmpty") : livePreviewText)
                                .font(.system(size: 12))
                                .foregroundColor(livePreviewText.isEmpty ? .secondary.opacity(0.6) : .primary)
                                .lineLimit(3)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(20)
            }

            Divider()

            // Sheet Footer Bar
            HStack(spacing: 10) {
                Button(L10n("common.cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    let s = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                    let r = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !s.isEmpty, !r.isEmpty else { return }
                    onSave(s, r)
                } label: {
                    Text(existingSnippet != nil ? L10n("common.save") : L10n("macro.action.addSubmit"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(shortcut.trimmingCharacters(in: .whitespaces).isEmpty || replacement.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, idealWidth: 560, minHeight: 480, maxHeight: 580)
    }

    private func appendToken(_ token: String) {
        if replacement.isEmpty {
            replacement = token
        } else if replacement.hasSuffix(" ") || replacement.hasSuffix("\n") {
            replacement += token
        } else {
            replacement += " " + token
        }
    }

    private func timeVariableChip(_ token: String, desc: String) -> some View {
        Button {
            appendToken(token)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 7.5, weight: .bold))
                Text(token)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                Text("(\(desc))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func systemVariableChip(_ token: String, desc: String) -> some View {
        Button {
            appendToken(token)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 7.5, weight: .bold))
                Text(token)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                Text("(\(desc))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.teal.opacity(0.12))
            .foregroundColor(.teal)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func constantVariableChip(_ token: String, desc: String) -> some View {
        Button {
            appendToken(token)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 7.5, weight: .bold))
                Text(token)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                Text("(\(desc))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.12))
            .foregroundColor(.green)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConstantEditorSheet (Spacious & Friendly Add/Edit Constant)

public struct ConstantEditorSheet: View {
    public let existingConstant: MacroConstant?
    public let onSave: (String, String) -> Void
    public let onCancel: () -> Void

    @State private var key: String = ""
    @State private var value: String = ""
    @ObservedObject var macroSettings = AppSettings.shared.macro

    public init(
        existingConstant: MacroConstant?,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingConstant = existingConstant
        self.onSave = onSave
        self.onCancel = onCancel
        _key = State(initialValue: existingConstant?.key ?? "")
        _value = State(initialValue: existingConstant?.value ?? "")
    }

    private var sanitizedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "$", with: "")
    }

    private var isDuplicateKey: Bool {
        let trimmed = sanitizedKey.lowercased()
        guard !trimmed.isEmpty else { return false }
        return macroSettings.constants.contains {
            $0.key.lowercased() == trimmed && $0.id != existingConstant?.id
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.gradient)
                        .frame(width: 34, height: 34)

                    Image(systemName: "character.textbox")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(existingConstant != nil ? L10n("macro.constant.editTitle") : L10n("macro.constant.createTitle"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    Text(L10n("macro.constant.subtitle"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // 1. Tên biến (Key)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(L10n("macro.constant.keyLabel"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        if isDuplicateKey {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text(L10n("macro.constant.duplicateWarning"))
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("{$")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        TextField(L10n("macro.constant.keyExample"), text: $key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))

                        Text("}")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    if !sanitizedKey.isEmpty {
                        HStack(spacing: 3) {
                            Text(L10n("macro.constant.tokenPrefix"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("{$" + sanitizedKey + "}")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }

                // 2. Giá trị (Value)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n("macro.constant.valueLabel"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    MacroTextArea(
                        placeholder: L10n("macro.constant.valueExample"),
                        text: $value,
                        minHeight: 90
                    )
                }

                // 3. Live Token Preview
                if !sanitizedKey.isEmpty && !value.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 8) {
                        Text("{$" + sanitizedKey + "}")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        Text(value.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 11.5))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer(minLength: 0)
            }
            .padding(20)

            Divider()

            // Sheet Footer Bar
            HStack(spacing: 10) {
                Button(L10n("common.cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    let k = sanitizedKey
                    let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !k.isEmpty, !v.isEmpty else { return }
                    onSave(k, v)
                } label: {
                    Text(existingConstant != nil ? L10n("common.save") : L10n("macro.constant.addBtn"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(sanitizedKey.isEmpty || value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 480, idealWidth: 500, minHeight: 380, maxHeight: 440)
    }
}
