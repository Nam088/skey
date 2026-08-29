import AppKit
import SwiftUI

// MARK: - AISettingsTab

public struct AISettingsTab: View {
    @ObservedObject var shortcutSettings = AppSettings.shared.shortcuts
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.aiModel"), icon: "cpu.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.aiPrompts"), icon: "text.bubble.fill"),
            SubTabItem(id: 2, title: L10n("settings.subtab.aiShortcuts"), icon: "command")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SubTabBar(items: subTabs, selectedTab: $navState.aiSubTab)

            VStack(spacing: 14) {
                switch navState.aiSubTab {
                case 0:
                    providerSection
                case 1:
                    promptsSection
                case 2:
                    shortcutsSection
                default:
                    EmptyView()
                }
            }
            .padding(.top, 2)
        }
    }

    private var providerSection: some View {
        SettingsGroup(title: L10n("ai.section.provider")) {
            SettingsRow(
                title: L10n("ai.option.service"),
                subtitle: L10n("ai.option.serviceDesc")
            ) {
                Picker("", selection: .constant("OpenAI")) {
                    Text("OpenAI (ChatGPT)").tag("OpenAI")
                    Text("Anthropic Claude").tag("Claude")
                    Text("Ollama (Cục bộ)").tag("Ollama")
                }
                .frame(width: 150)
            }

            SettingsRow(
                title: L10n("ai.option.apiKey"),
                subtitle: L10n("ai.option.apiKeyDesc"),
                showDivider: false
            ) {
                SecureField("sk-...", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
        }
    }

    private var promptsSection: some View {
        SettingsGroup(title: L10n("ai.section.prompts")) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 38))
                    .foregroundColor(.pink)
                Text(L10n("ai.headline"))
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n("ai.headlineDesc"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var shortcutsSection: some View {
        SettingsGroup(title: L10n("ai.section.shortcuts")) {
            SettingsRow(
                title: L10n("ai.option.shortcut"),
                subtitle: L10n("ai.option.shortcutDesc"),
                showDivider: false
            ) {
                ShortcutPickerView(
                    preset: $shortcutSettings.aiPreset,
                    shortcut: $shortcutSettings.aiShortcut,
                    presets: ShortcutSettings.aiPresets,
                    target: .ai
                )
            }
        }
    }
}
