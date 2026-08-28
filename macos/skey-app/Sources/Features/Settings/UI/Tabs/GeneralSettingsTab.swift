import AppKit
import SwiftUI

// MARK: - GeneralSettingsTab

public struct GeneralSettingsTab: View {
    @ObservedObject var generalSettings = AppSettings.shared.general
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.basic"), icon: "gearshape.2.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.permissions"), icon: "hand.raised.fill"),
            SubTabItem(id: 2, title: L10n("settings.subtab.logs"), icon: "doc.text.magnifyingglass")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SubTabBar(items: subTabs, selectedTab: $navState.generalSubTab)

            ScrollView {
                VStack(spacing: 20) {
                    switch navState.generalSubTab {
                    case 0:
                        basicSection
                    case 1:
                        permissionsSection
                    case 2:
                        logsSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(L10n("app.title")),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - 1. Cơ bản (Basic)

    private var basicSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("general.section.system")) {
                SettingsRow(
                    title: L10n("general.option.launchAtLogin"),
                    subtitle: L10n("general.option.launchAtLoginDesc")
                ) {
                    Toggle("", isOn: $generalSettings.launchAtLogin)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("general.option.appLanguage"),
                    subtitle: L10n("general.option.appLanguageDesc")
                ) {
                    Picker("", selection: Binding(
                        get: { LocalizationService.shared.currentLanguage },
                        set: { LocalizationService.shared.currentLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .frame(width: 150)
                }

                SettingsRow(
                    title: L10n("general.option.checkUpdates"),
                    subtitle: L10n("general.option.checkUpdatesDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: $generalSettings.checkUpdates)
                        .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - 2. Quyền hệ thống (Permissions)

    private var permissionsSection: some View {
        SettingsGroup(title: L10n("general.section.permissions")) {
            SettingsRow(
                title: L10n("general.option.ax"),
                subtitle: L10n("general.option.axDesc")
            ) {
                Button(L10n("general.action.openSettings")) {
                    PermissionsService.shared.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
            }

            SettingsRow(
                title: L10n("general.option.im"),
                subtitle: L10n("general.option.imDesc"),
                showDivider: false
            ) {
                Button(L10n("general.action.openSettings")) {
                    PermissionsService.shared.openInputMonitoringSettings()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 3. Nhật ký & Dữ liệu (Logs & Data / Backup & Restore)

    private var logsSection: some View {
        VStack(spacing: 16) {
            // Backup & Restore Full App Settings
            SettingsGroup(title: L10n("general.section.backup")) {
                SettingsRow(
                    title: L10n("general.option.exportSettings"),
                    subtitle: L10n("general.option.exportSettingsDesc")
                ) {
                    Button(L10n("general.action.exportSettingsBtn")) {
                        SettingsBackupManager.shared.exportSettings { success in
                            if success {
                                alertMessage = L10n("general.backup.exportSuccess")
                                showAlert = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }

                SettingsRow(
                    title: L10n("general.option.importSettings"),
                    subtitle: L10n("general.option.importSettingsDesc"),
                    showDivider: false
                ) {
                    Button(L10n("general.action.importSettingsBtn")) {
                        SettingsBackupManager.shared.importSettings { success in
                            alertMessage = success ? L10n("general.backup.importSuccess") : L10n("general.backup.importFailed")
                            showAlert = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Utility Tools (Cleaner)
            SettingsGroup(title: L10n("cleaner.title")) {
                SettingsRow(
                    title: L10n("cleaner.title"),
                    subtitle: L10n("cleaner.desc"),
                    showDivider: false
                ) {
                    Button(L10n("cleaner.action.start")) {
                        KeyboardCleanerController.shared.startCleaning()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Activity Logs
            SettingsGroup(title: L10n("general.section.logs")) {
                SettingsRow(
                    title: L10n("general.option.openLog"),
                    subtitle: L10n("general.option.openLogDesc")
                ) {
                    Button(L10n("general.action.openLogBtn")) {
                        let path = SKeyLogger.shared.logFilePath
                        if !FileManager.default.fileExists(atPath: path) {
                            _ = try? "".write(toFile: path, atomically: true, encoding: .utf8)
                        }
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                    .buttonStyle(.bordered)
                }

                SettingsRow(
                    title: L10n("general.option.clearLog"),
                    subtitle: L10n("general.option.clearLogDesc"),
                    showDivider: false
                ) {
                    Button(L10n("general.action.clearLogBtn")) {
                        LogStore.shared.clear()
                        try? FileManager.default.removeItem(atPath: SKeyLogger.shared.logFilePath)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Factory Reset
            Button(role: .destructive) {
                AppSettings.shared.resetAll()
            } label: {
                Text(L10n("general.action.resetDefaults"))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
        }
    }
}
