import AppKit
import SwiftUI

// MARK: - AboutSettingsTab

public struct AboutSettingsTab: View {
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var updater = UpdateCheckerService.shared

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    SKeyLogoView(size: 64)

                    Text(L10n("about.title"))
                        .font(.system(size: 22, weight: .bold))

                    Text(String(format: L10n("about.version"), updater.currentVersion))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(L10n("about.description"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 8)

                SettingsGroup {
                    SettingsRow(title: L10n("about.author"), showDivider: true) {
                        Text("Nam088")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    SettingsRow(title: L10n("about.opensource"), showDivider: true) {
                        Button("GitHub") {
                            if let url = URL(string: "https://github.com/Nam088/skey") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    // In-App Update Row
                    updateRow
                }
                .frame(maxWidth: 440)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Update Row & Interactive States

    @ViewBuilder
    private var updateRow: some View {
        switch updater.state {
        case .idle:
            SettingsRow(
                title: L10n("about.checkUpdateBtn"),
                subtitle: updater.lastCheckDate.map { String(format: L10n("about.checkUpdateLastCheck"), formatDate($0)) },
                showDivider: false
            ) {
                Button(L10n("about.checkUpdateBtn")) {
                    updater.checkForUpdates(isManual: true)
                }
                .buttonStyle(.bordered)
            }

        case .checking:
            SettingsRow(
                title: L10n("about.checkUpdateChecking"),
                showDivider: false
            ) {
                ProgressView()
                    .controlSize(.small)
            }

        case .upToDate:
            SettingsRow(
                title: String(format: L10n("about.checkUpdateUpToDate"), updater.currentVersion),
                subtitle: updater.lastCheckDate.map { String(format: L10n("about.checkUpdateLastCheck"), formatDate($0)) },
                showDivider: false
            ) {
                Button {
                    updater.checkForUpdates(isManual: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(L10n("about.checkUpdateBtn"))
            }

        case .updateAvailable(let version, _, let htmlUrl, let downloadUrl):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)

                    Text(String(format: L10n("about.checkUpdateAvailable"), version))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()
                }

                HStack(spacing: 10) {
                    if let downloadUrl = downloadUrl {
                        Button(L10n("about.checkUpdateActionUpdate")) {
                            updater.startUpdate(downloadUrl: downloadUrl)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button(L10n("about.checkUpdateActionView")) {
                        NSWorkspace.shared.open(htmlUrl)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(format: L10n("about.checkUpdateDownloading"), Int(progress * 100)))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        case .extracting:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n("about.checkUpdateExtracting"))
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        case .readyToRestart:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n("about.checkUpdateRestarting"))
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        case .error(let message):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    Text(String(format: L10n("about.checkUpdateError"), message))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(L10n("about.checkUpdateBtn")) {
                        updater.checkForUpdates(isManual: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
