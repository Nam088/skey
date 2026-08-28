import AppKit
import SwiftUI

// MARK: - KeyboardSettingsTab

public struct KeyboardSettingsTab: View {
    @ObservedObject var keyboardSettings = AppSettings.shared.keyboard
    @ObservedObject var macroSettings = AppSettings.shared.macro
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.inputMethod"), icon: "keyboard"),
            SubTabItem(id: 1, title: L10n("settings.subtab.orthography"), icon: "textformat.abc"),
            SubTabItem(id: 2, title: L10n("settings.subtab.quickTyping"), icon: "bolt.fill"),
            SubTabItem(id: 3, title: L10n("settings.subtab.smartSwitch"), icon: "arrow.triangle.2.circlepath")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SubTabBar(items: subTabs, selectedTab: $navState.keyboardSubTab)

            ScrollView {
                VStack(spacing: 20) {
                    switch navState.keyboardSubTab {
                    case 0:
                        inputMethodSection
                    case 1:
                        orthographySection
                    case 2:
                        quickTypingSection
                    case 3:
                        smartAppSwitchSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
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
                    showDivider: false
                ) {
                    HStack(spacing: 10) {
                        KeyCapBadge("⌥Z")
                        Toggle("", isOn: Binding(
                            get: { keyboardSettings.isVietnamese },
                            set: {
                                keyboardSettings.isVietnamese = $0
                                EventTapManager.shared.setLanguage(vietnamese: $0)
                            }
                        ))
                        .toggleStyle(.switch)
                    }
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

    // MARK: - 4. Chuyển app thông minh

    private var smartAppSwitchSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("keyboard.section.smartSwitch")) {
                SettingsRow(
                    title: L10n("keyboard.option.smartSwitch"),
                    subtitle: L10n("keyboard.option.smartSwitchDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: $keyboardSettings.smartAppSwitchEnabled)
                        .toggleStyle(.switch)
                }
            }

            SettingsGroup(title: L10n("keyboard.section.smartSwitchApps")) {
                ForEach([
                    ("Xcode", "com.apple.dt.Xcode", "hammer.fill"),
                    ("Visual Studio Code", "com.microsoft.VSCode", "curlybraces"),
                    ("Terminal", "com.apple.Terminal", "terminal.fill"),
                    ("iTerm2", "com.googlecode.iterm2", "terminal.fill"),
                    ("Warp", "dev.warp.Warp-Stable", "bolt.fill"),
                    ("Cursor", "com.todesktop.230313mzl4w4u92", "wand.and.stars"),
                    ("IntelliJ IDEA", "com.jetbrains.intellij", "cube.fill")
                ], id: \.1) { name, bundleID, icon in
                    SettingsRow(
                        title: name,
                        subtitle: bundleID,
                        showDivider: bundleID != "com.jetbrains.intellij"
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text(L10n("keyboard.status.auto"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
