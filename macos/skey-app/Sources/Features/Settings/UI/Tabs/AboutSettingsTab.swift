import AppKit
import SwiftUI

// MARK: - AboutSettingsTab

public struct AboutSettingsTab: View {
    @ObservedObject var loc = LocalizationService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text(L10n("about.title"))
                    .font(.system(size: 24, weight: .bold))

                Text(L10n("about.version"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(L10n("about.description"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            SettingsGroup {
                SettingsRow(title: L10n("about.author"), showDivider: true) {
                    Text("nam088")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                SettingsRow(title: L10n("about.opensource"), showDivider: false) {
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/nam088/skey") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
