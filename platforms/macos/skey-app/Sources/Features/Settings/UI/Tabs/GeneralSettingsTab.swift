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
        VStack(alignment: .leading, spacing: 14) {
            SubTabBar(items: subTabs, selectedTab: $navState.generalSubTab)

            VStack(spacing: 14) {
                switch navState.generalSubTab {
                case 0:
                    basicSection
                case 1:
                    permissionsSection
                        .onAppear {
                            // Refresh permission status when tab appears
                            PermissionsService.shared.refreshPermissions()
                        }
                case 2:
                    logsSection
                default:
                    EmptyView()
                }
            }
            .padding(.top, 2)
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
                    title: L10n("general.option.theme"),
                    subtitle: L10n("general.option.themeDesc")
                ) {
                    Picker("", selection: $generalSettings.appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                SettingsRow(
                    title: L10n("general.option.checkUpdates"),
                    subtitle: L10n("general.option.checkUpdatesDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: $generalSettings.checkUpdates)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("general.option.inlineCalculator"),
                    subtitle: L10n("general.option.inlineCalculatorDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: $generalSettings.inlineCalculatorEnabled)
                        .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - 2. Quyền hệ thống (Permissions)

    @ObservedObject private var permissions = PermissionsService.shared

    private var permissionsSection: some View {
        SettingsGroup(title: L10n("general.section.permissions")) {
            SettingsRow(
                title: L10n("general.option.ax"),
                subtitle: permissionStatusText(granted: permissions.hasAccessibilityPermission)
            ) {
                HStack(spacing: 8) {
                    permissionBadge(granted: permissions.hasAccessibilityPermission)
                    Button(L10n("general.action.openSettings")) {
                        PermissionsService.shared.openAccessibilitySettings()
                        // Refresh after delay (user might grant permission in System Settings)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            PermissionsService.shared.refreshPermissions()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            SettingsRow(
                title: L10n("general.option.im"),
                subtitle: permissionStatusText(granted: permissions.hasInputMonitoringPermission),
                showDivider: false
            ) {
                HStack(spacing: 8) {
                    permissionBadge(granted: permissions.hasInputMonitoringPermission)
                    Button(L10n("general.action.openSettings")) {
                        PermissionsService.shared.openInputMonitoringSettings()
                        // Refresh after delay (user might grant permission in System Settings)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            PermissionsService.shared.refreshPermissions()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Permission Status Helpers

    private func permissionStatusText(granted: Bool) -> String {
        granted ? L10n("permissions.status.granted") : L10n("permissions.status.required")
    }

    @ViewBuilder
    private func permissionBadge(granted: Bool) -> some View {
        if granted {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
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

            // Activity & Debug Logs (Strictly protected in Release builds)
            SettingsGroup(title: L10n("general.section.logs")) {
                #if DEBUG
                SettingsRow(
                    title: L10n("general.option.debugMode"),
                    subtitle: L10n("general.option.debugModeDesc")
                ) {
                    Toggle("", isOn: $generalSettings.isDebugMode)
                        .toggleStyle(.switch)
                }

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
                    .disabled(!generalSettings.isDebugMode)
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
                #else
                SettingsRow(
                    title: L10n("general.option.debugMode"),
                    subtitle: L10n("general.option.debugModeDisabledRelease"),
                    showDivider: false
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                        Text(L10n("general.status.releaseProtected"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
                #endif
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
