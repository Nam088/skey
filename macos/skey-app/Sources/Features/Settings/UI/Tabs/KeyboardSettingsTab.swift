import AppKit
import SwiftUI

// MARK: - KeyboardSettingsTab

public struct KeyboardSettingsTab: View {
    @ObservedObject var keyboardSettings = AppSettings.shared.keyboard
    @ObservedObject var macroSettings = AppSettings.shared.macro
    @ObservedObject var shortcutSettings = AppSettings.shared.shortcuts
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    @State private var isShowingAddSheet: Bool = false

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.inputMethod"), icon: "keyboard"),
            SubTabItem(id: 1, title: L10n("settings.subtab.typingRules"), icon: "textformat.abc"),
            SubTabItem(id: 2, title: L10n("settings.subtab.appManagement"), icon: "app.badge")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubTabBar(items: subTabs, selectedTab: $navState.keyboardSubTab)

            ScrollView {
                VStack(spacing: 14) {
                    switch navState.keyboardSubTab {
                    case 0:
                        inputMethodSection
                    case 1:
                        typingRulesSection
                    case 2:
                        appManagementSection
                    default:
                        inputMethodSection
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.automatic)
        }
    }

    // MARK: - Combined Sections

    private var typingRulesSection: some View {
        VStack(spacing: 20) {
            orthographySection
            quickTypingSection
        }
    }

    private var appManagementSection: some View {
        VStack(spacing: 20) {
            smartAppSwitchSection
            excludedAppsSection
        }
    }

    // MARK: - 1. Kiểu gõ

    private var inputMethodSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("keyboard.section.inputMethod")) {
                SettingsRow(
                    title: L10n("keyboard.option.primaryMethod"),
                    subtitle: L10n("keyboard.option.primaryMethodDesc")
                ) {
                    Picker("", selection: Binding(
                        get: { keyboardSettings.inputMethod },
                        set: {
                            keyboardSettings.inputMethod = $0
                            EventTapManager.shared.engine.setInputMethod($0)
                        }
                    )) {
                        Text("Telex").tag(InputMethodType.telex)
                        Text("Simple Telex").tag(InputMethodType.simpleTelex)
                        Text("VNI").tag(InputMethodType.vni)
                        Text("VIQR").tag(InputMethodType.viqr)
                    }
                    .frame(width: 140)
                }

                SettingsRow(
                    title: L10n("keyboard.option.charset"),
                    subtitle: L10n("keyboard.option.charsetDesc"),
                    showDivider: false
                ) {
                    Picker("", selection: $keyboardSettings.charset) {
                        Text(L10n("keyboard.charset.unicode")).tag("Unicode")
                        Text(L10n("keyboard.charset.tcvn3")).tag("TCVN3")
                        Text(L10n("keyboard.charset.vni")).tag("VNI Windows")
                    }
                    .frame(width: 160)
                }
            }

            SettingsGroup(title: L10n("keyboard.section.mode")) {
                SettingsRow(
                    title: L10n("keyboard.option.enableVietnamese"),
                    subtitle: L10n("keyboard.option.enableVietnameseDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: Binding(
                        get: { keyboardSettings.isVietnamese },
                        set: {
                            keyboardSettings.isVietnamese = $0
                            EventTapManager.shared.setLanguage(vietnamese: $0)
                        }
                    ))
                    .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("keyboard.shortcut.toggleTitle"),
                    subtitle: L10n("keyboard.shortcut.toggleSubtitle"),
                    showDivider: false
                ) {
                    ShortcutPickerView(
                        preset: $shortcutSettings.languageTogglePreset,
                        shortcut: $shortcutSettings.languageToggleShortcut,
                        presets: ShortcutSettings.languagePresets,
                        target: .languageToggle
                    )
                }
            }
        }
    }

    // MARK: - 2. Bỏ dấu & Chính tả

    private var orthographySection: some View {
        SettingsGroup(title: L10n("keyboard.section.rules")) {
            SettingsRow(
                title: L10n("keyboard.options.spell_check"),
                subtitle: L10n("keyboard.option.spellCheckDesc")
            ) {
                Toggle("", isOn: Binding(
                    get: { keyboardSettings.spellCheck },
                    set: {
                        keyboardSettings.spellCheck = $0
                        EventTapManager.shared.engine.setSpellCheck($0)
                    }
                ))
                .toggleStyle(.switch)
            }

            SettingsRow(
                title: L10n("keyboard.options.free_marking"),
                subtitle: L10n("keyboard.option.freeMarkingDesc")
            ) {
                Toggle("", isOn: Binding(
                    get: { keyboardSettings.freeMarking },
                    set: {
                        keyboardSettings.freeMarking = $0
                        EventTapManager.shared.engine.setFreeMarking($0)
                    }
                ))
                .toggleStyle(.switch)
            }

            SettingsRow(
                title: L10n("keyboard.options.modern_style"),
                subtitle: L10n("keyboard.option.modernStyleDesc")
            ) {
                Toggle("", isOn: Binding(
                    get: { keyboardSettings.modernStyle },
                    set: {
                        keyboardSettings.modernStyle = $0
                        EventTapManager.shared.engine.setModernStyle($0)
                    }
                ))
                .toggleStyle(.switch)
            }

            SettingsRow(
                title: L10n("keyboard.advanced.swallowed_restore"),
                subtitle: L10n("keyboard.option.swallowedKeyDesc"),
                showDivider: false
            ) {
                Toggle("", isOn: Binding(
                    get: { keyboardSettings.swallowedKeyRestore },
                    set: {
                        keyboardSettings.swallowedKeyRestore = $0
                        EventTapManager.shared.engine.setSwallowedKeyRestore($0)
                    }
                ))
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - 3. Gõ nhanh

    private var quickTypingSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("keyboard.section.quickTelex")) {
                SettingsRow(
                    title: L10n("keyboard.advanced.quick_telex"),
                    subtitle: L10n("keyboard.option.quickTelexDesc")
                ) {
                    Toggle("", isOn: Binding(
                        get: { keyboardSettings.quickTelex },
                        set: {
                            keyboardSettings.quickTelex = $0
                            EventTapManager.shared.engine.setQuickTelex($0)
                        }
                    ))
                    .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("keyboard.option.quickStartConsonant"),
                    subtitle: L10n("keyboard.option.quickStartConsonantDesc")
                ) {
                    Toggle("", isOn: Binding(
                        get: { keyboardSettings.quickStartConsonant },
                        set: {
                            keyboardSettings.quickStartConsonant = $0
                            EventTapManager.shared.engine.setQuickStartConsonant($0)
                        }
                    ))
                    .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("keyboard.option.quickEndConsonant"),
                    subtitle: L10n("keyboard.option.quickEndConsonantDesc")
                ) {
                    Toggle("", isOn: Binding(
                        get: { keyboardSettings.quickEndConsonant },
                        set: {
                            keyboardSettings.quickEndConsonant = $0
                            EventTapManager.shared.engine.setQuickEndConsonant($0)
                        }
                    ))
                    .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("keyboard.option.upperCaseFirst"),
                    subtitle: L10n("keyboard.option.upperCaseFirstDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: Binding(
                        get: { keyboardSettings.upperCaseFirstChar },
                        set: {
                            keyboardSettings.upperCaseFirstChar = $0
                            EventTapManager.shared.engine.setUpperCaseFirstChar($0)
                        }
                    ))
                    .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - 3. Quản lý Ứng dụng (Smart Switch & Excluded Apps)

    private var smartAppSwitchSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("keyboard.section.smartSwitch")) {
                SettingsRow(
                    title: L10n("keyboard.option.smartSwitch"),
                    subtitle: L10n("keyboard.option.smartSwitchDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: $keyboardSettings.smartAppSwitchEnabled)
                        .toggleStyle(.switch)
                }
            }
        }
    }

    private var excludedAppsSection: some View {
        SettingsGroup(title: L10n("keyboard.section.excludedApps")) {
            // 1. Master Toggle
            SettingsRow(
                title: L10n("keyboard.excluded.enableMaster"),
                subtitle: L10n("keyboard.excluded.enableMasterDesc"),
                showDivider: true
            ) {
                Toggle("", isOn: $keyboardSettings.isExclusionEnabled)
                    .toggleStyle(.switch)
            }

            // 2. Action Bar & App List Area
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Text(
                        keyboardSettings.excludedApps.isEmpty
                            ? L10n("keyboard.excluded.noApps")
                            : "\(keyboardSettings.excludedApps.count) \(L10n("keyboard.excluded.appsCount"))"
                    )
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)

                    Spacer()

                    if !keyboardSettings.excludedApps.isEmpty {
                        Button(role: .destructive) {
                            withAnimation {
                                keyboardSettings.clearExcludedApps()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text(L10n("keyboard.excluded.clearAll"))
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.trailing, 4)
                    }

                    Button {
                        isShowingAddSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text(L10n("keyboard.excluded.addApp"))
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                if keyboardSettings.excludedApps.isEmpty {
                    // Empty State
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.app")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 4)

                        Text(L10n("keyboard.excluded.emptyTitle"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(L10n("keyboard.excluded.emptyDesc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button {
                            isShowingAddSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                Text(L10n("keyboard.excluded.addFirst"))
                            }
                            .font(.system(size: 11.5, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Apps List
                    Divider()
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(keyboardSettings.excludedApps.enumerated()), id: \.element.bundleID) { index, app in
                            HStack(spacing: 12) {
                                Image(nsImage: getAppIcon(bundleID: app.bundleID))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text(app.bundleID)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { app.isEnabled },
                                    set: { _ in
                                        keyboardSettings.toggleExcludedApp(bundleID: app.bundleID)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        keyboardSettings.removeExcludedApp(bundleID: app.bundleID)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help(L10n("keyboard.excluded.deleteTooltip"))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            if index < keyboardSettings.excludedApps.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddExcludedAppSheet(
                onAdd: { bid, name in
                    keyboardSettings.addExcludedApp(bundleID: bid, name: name)
                },
                isPresented: $isShowingAddSheet
            )
        }
    }

    private func getAppIcon(bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

// MARK: - RunningAppInfo Model

public struct RunningAppInfo: Identifiable {
    public var id: String { bundleID }
    public let name: String
    public let bundleID: String
    public let icon: NSImage
}

// MARK: - AddExcludedAppSheet

public struct AddExcludedAppSheet: View {
    let onAdd: (String, String) -> Void
    @Binding var isPresented: Bool

    @State private var selectedTab: Int = 0
    @State private var searchQuery: String = ""
    @State private var customName: String = ""
    @State private var customBundleID: String = ""
    @State private var runningApps: [RunningAppInfo] = []

    public init(onAdd: @escaping (String, String) -> Void, isPresented: Binding<Bool>) {
        self.onAdd = onAdd
        self._isPresented = isPresented
    }

    private var filteredRunningApps: [RunningAppInfo] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return runningApps
        }
        let q = searchQuery.lowercased()
        return runningApps.filter { $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Sheet Header
            HStack {
                Text(L10n("keyboard.excluded.sheetTitle"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)

            // Picker Segmented
            Picker("", selection: $selectedTab) {
                Text(L10n("keyboard.excluded.tabRunning")).tag(0)
                Text(L10n("keyboard.excluded.tabBrowse")).tag(1)
                Text(L10n("keyboard.excluded.tabCustom")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)

            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    runningAppsView
                case 1:
                    browseFileView
                case 2:
                    customIDView
                default:
                    EmptyView()
                }
            }
            .frame(height: 250)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(L10n("common.cancel")) {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(width: 460)
        .onAppear {
            loadRunningApps()
        }
    }

    private var runningAppsView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(L10n("keyboard.excluded.searchRunningPlaceholder"), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(7)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 18)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredRunningApps) { app in
                        Button {
                            onAdd(app.bundleID, app.name)
                            isPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 22, height: 22)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(app.bundleID)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var browseFileView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text(L10n("keyboard.excluded.browseDesc"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                browseAppFile()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text(L10n("keyboard.excluded.browseBtn"))
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
        }
    }

    private var customIDView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n("keyboard.excluded.customNameLabel"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. League of Legends", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n("keyboard.excluded.customBundleIDLabel"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. com.riotgames.LeagueofLegends", text: $customBundleID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack {
                Spacer()
                Button(L10n("keyboard.excluded.customAddBtn")) {
                    let bid = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !bid.isEmpty else { return }
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onAdd(bid, name.isEmpty ? bid : name)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(customBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private func loadRunningApps() {
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        runningApps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard let bid = app.bundleIdentifier, !bid.isEmpty, bid != myBundleID else { return false }
                return app.activationPolicy == .regular
            }
            .compactMap { app in
                guard let bid = app.bundleIdentifier else { return nil }
                let name = app.localizedName ?? bid
                let icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
                return RunningAppInfo(name: name, bundleID: bid, icon: icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func browseAppFile() {
        let panel = NSOpenPanel()
        panel.title = L10n("keyboard.excluded.chooseAppTitle")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            let bid = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            onAdd(bid, name)
            isPresented = false
        }
    }
}

