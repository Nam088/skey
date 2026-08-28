import AppKit
import SwiftUI

// MARK: - SubTabItem Model

public struct SubTabItem: Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let icon: String

    public init(id: Int, title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

// MARK: - Full-Width Modern Pill SubTabBar Component

public struct SubTabBar: View {
    public let items: [SubTabItem]
    @Binding public var selectedTab: Int
    @Namespace private var pillNamespace

    public init(items: [SubTabItem], selectedTab: Binding<Int>) {
        self.items = items
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = selectedTab == item.id
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        selectedTab = item.id
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .blue : .secondary)

                        Text(item.title)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 4)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.12), radius: 2.5, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                                )
                                .matchedGeometryEffect(id: "activeSubTabPill", in: pillNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.quaternaryLabelColor).opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Reusable Settings Group Container (Spacious Card)

public struct SettingsGroup<Content: View>: View {
    public let title: String?
    public let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .tracking(0.5)
                    .padding(.leading, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 4, x: 0, y: 1.5)
        }
    }
}

// MARK: - Reusable Settings Row (Spacious Layout)

public struct SettingsRow<Control: View>: View {
    public let title: String
    public var subtitle: String?
    public var showDivider: Bool
    public let control: Control

    public init(
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.control = control()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 16)
                control
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Reusable KeyCap Badge

public struct KeyCapBadge: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 0.5)
    }
}
