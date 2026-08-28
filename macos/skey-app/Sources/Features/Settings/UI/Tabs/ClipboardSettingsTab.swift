import AppKit
import SwiftUI

// MARK: - ClipboardSettingsTab

public struct ClipboardSettingsTab: View {
    @ObservedObject var clipboardSettings = AppSettings.shared.clipboard
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    private var subTabs: [SubTabItem] {
        [
            SubTabItem(id: 0, title: L10n("settings.subtab.general"), icon: "gearshape.fill"),
            SubTabItem(id: 1, title: L10n("settings.subtab.storage"), icon: "internaldrive.fill"),
            SubTabItem(id: 2, title: L10n("settings.subtab.appearance"), icon: "paintpalette.fill"),
            SubTabItem(id: 3, title: L10n("settings.subtab.pins"), icon: "pin.fill"),
            SubTabItem(id: 4, title: L10n("settings.subtab.privacy"), icon: "lock.shield.fill")
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SubTabBar(items: subTabs, selectedTab: $navState.clipboardSubTab)

            ScrollView {
                VStack(spacing: 20) {
                    switch navState.clipboardSubTab {
                    case 0:
                        generalSection
                    case 1:
                        storageSection
                    case 2:
                        appearanceSection
                    case 3:
                        pinsSection
                    case 4:
                        privacySection
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 1. Chung (General)

    private var generalSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("clipboard.section.management")) {
                SettingsRow(
                    title: L10n("clipboard.option.enableMonitor"),
                    subtitle: L10n("clipboard.option.enableMonitorDesc")
                ) {
                    Toggle("", isOn: $clipboardSettings.isEnabled)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("clipboard.option.shortcut"),
                    subtitle: L10n("clipboard.option.shortcutDesc")
                ) {
                    KeyCapBadge("⌥V")
                }

                SettingsRow(
                    title: L10n("clipboard.option.searchType"),
                    subtitle: L10n("clipboard.option.searchTypeDesc"),
                    showDivider: false
                ) {
                    Picker("", selection: $clipboardSettings.searchMode) {
                        Text(L10n("clipboard.search.fuzzy")).tag("Fuzzy")
                        Text(L10n("clipboard.search.exact")).tag("Exact")
                    }
                    .frame(width: 150)
                }
            }

            SettingsGroup(title: L10n("clipboard.section.pasteActions")) {
                SettingsRow(
                    title: L10n("clipboard.option.autoPaste"),
                    subtitle: L10n("clipboard.option.autoPasteDesc"),
                    showDivider: true
                ) {
                    Toggle("", isOn: $clipboardSettings.autoPaste)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("clipboard.option.plainText"),
                    subtitle: L10n("clipboard.option.plainTextDesc"),
                    showDivider: false
                ) {
                    HStack(spacing: 8) {
                        KeyCapBadge("⇧⏎")
                        Toggle("", isOn: $clipboardSettings.pasteAsPlainText)
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }

    // MARK: - 2. Lưu trữ (Storage)

    private var storageSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("clipboard.section.dataTypes")) {
                SettingsRow(
                    title: L10n("clipboard.option.saveText"),
                    subtitle: L10n("clipboard.option.saveTextDesc")
                ) {
                    Toggle("", isOn: $clipboardSettings.saveText)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("clipboard.option.saveImages"),
                    subtitle: L10n("clipboard.option.saveImagesDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: $clipboardSettings.saveImages)
                        .toggleStyle(.switch)
                }
            }

            SettingsGroup(title: L10n("clipboard.section.limits")) {
                SettingsRow(
                    title: L10n("clipboard.option.maxItems"),
                    subtitle: L10n("clipboard.option.maxItemsDesc")
                ) {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(clipboardSettings.historyLimit) },
                                set: { clipboardSettings.historyLimit = Int($0) }
                            ),
                            in: 50...1000,
                            step: 50
                        )
                        .frame(width: 130)

                        Text("\(clipboardSettings.historyLimit)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                SettingsRow(
                    title: L10n("clipboard.option.sortOrder"),
                    subtitle: L10n("clipboard.option.sortOrderDesc"),
                    showDivider: false
                ) {
                    Picker("", selection: $clipboardSettings.sortOrder) {
                        Text(L10n("preview.lastCopyTime")).tag(ClipboardSortOrder.lastCopiedAt)
                        Text(L10n("preview.firstCopyTime")).tag(ClipboardSortOrder.firstCopiedAt)
                        Text(L10n("clipboard.sort.copies")).tag(ClipboardSortOrder.numberOfCopies)
                    }
                    .frame(width: 160)
                }
            }

            Button(role: .destructive) {
                Task {
                    try? await ClipboardFeature.shared.store.clearAll()
                }
            } label: {
                Text(L10n("clipboard.action.clearAll"))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 3. Giao diện (Appearance)

    private var appearanceSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("clipboard.section.position")) {
                SettingsRow(title: L10n("clipboard.option.popupPosition")) {
                    Picker("", selection: $clipboardSettings.popupPosition) {
                        Text(L10n("clipboard.pos.cursor")).tag(ClipboardPopupPosition.cursor)
                        Text(L10n("clipboard.pos.statusItem")).tag(ClipboardPopupPosition.statusItem)
                    }
                    .frame(width: 160)
                }

                SettingsRow(title: L10n("clipboard.option.pinLocation")) {
                    Picker("", selection: $clipboardSettings.pinTo) {
                        Text(L10n("clipboard.pin.top")).tag(ClipboardPinTo.top)
                        Text(L10n("clipboard.pin.bottom")).tag(ClipboardPinTo.bottom)
                    }
                    .frame(width: 160)
                }

                SettingsRow(title: L10n("clipboard.option.thumbHeight"), showDivider: false) {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(clipboardSettings.imageThumbnailHeight) },
                                set: { clipboardSettings.imageThumbnailHeight = Int($0) }
                            ),
                            in: 30...80,
                            step: 5
                        )
                        .frame(width: 120)

                        Text("\(clipboardSettings.imageThumbnailHeight) px")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }

            SettingsGroup(title: L10n("clipboard.section.previewAux")) {
                SettingsRow(
                    title: L10n("clipboard.option.hoverPreview"),
                    subtitle: L10n("clipboard.option.hoverPreviewDesc")
                ) {
                    Toggle("", isOn: $clipboardSettings.openPreviewAutomatically)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("clipboard.option.appIcons"),
                    subtitle: L10n("clipboard.option.appIconsDesc")
                ) {
                    Toggle("", isOn: $clipboardSettings.showApplicationIcons)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n("clipboard.option.colorSwatch"),
                    subtitle: L10n("clipboard.option.colorSwatchDesc"),
                    showDivider: false
                ) {
                    Toggle("", isOn: $clipboardSettings.showHexColorSwatch)
                        .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - 4. Mục đã ghim (Pins)

    private var pinsSection: some View {
        SettingsGroup(title: L10n("clipboard.section.pinsTitle")) {
            VStack(spacing: 12) {
                Image(systemName: "pin.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.orange)
                Text(L10n("clipboard.pins.headline"))
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n("clipboard.pins.desc"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - 5. Bảo mật & Loại trừ (Privacy)

    private var privacySection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: L10n("clipboard.section.privacy")) {
                ForEach([
                    ("1Password", "com.1password.1password", "lock.shield.fill"),
                    ("Bitwarden", "com.bitwarden.desktop", "shield.checkered"),
                    ("Keychain Access", "com.apple.keychainaccess", "key.fill"),
                    ("KeePassXC", "org.keepassxc.keepassxc", "lock.fill")
                ], id: \.1) { name, bundleID, icon in
                    SettingsRow(
                        title: name,
                        subtitle: bundleID,
                        showDivider: bundleID != "org.keepassxc.keepassxc"
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(L10n("clipboard.status.protected"))
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
