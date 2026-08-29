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

// MARK: - Full-Width Modern Liquid Glass SubTabBar Component

public struct SubTabBar: View {
    public let items: [SubTabItem]
    @Binding public var selectedTab: Int
    @Namespace private var pillNamespace

    public init(items: [SubTabItem], selectedTab: Binding<Int>) {
        self.items = items
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 5) {
            ForEach(items) { item in
                let isSelected = selectedTab == item.id
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        selectedTab = item.id
                    }
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .blue : .secondary)

                        Text(item.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background {
                        if isSelected {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.6),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.75
                                    )
                            }
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.3))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            }
        )
    }
}

// MARK: - Reusable Settings Group Container (macOS Liquid Glass Card)

public struct SettingsGroup<Content: View>: View {
    public let title: String?
    public let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .tracking(0.6)
                    .padding(.leading, 8)
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
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
            .padding(.horizontal, 18)
            .padding(.vertical, 13)

            if showDivider {
                Divider()
                    .opacity(0.5)
                    .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Reusable KeyCap Badge

public struct KeyCapBadge: View {
    public let text: String
    public var isHighlighted: Bool = false

    public init(_ text: String, isHighlighted: Bool = false) {
        self.text = text
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundColor(isHighlighted ? .accentColor : .primary)
            .frame(minWidth: text.count == 1 ? 19 : 24, minHeight: 20)
            .padding(.horizontal, text.count > 1 ? 6 : 4)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHighlighted ? 0.35 : 0.2),
                                    Color.white.opacity(isHighlighted ? 0.1 : 0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isHighlighted ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.45),
                                isHighlighted ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

// MARK: - SKey Official Logo View (Concept B Negative Space S)

public struct SKeyLogoView: View {
    public var size: CGFloat

    public init(size: CGFloat = 38) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background Squircle
            RoundedRectangle(cornerRadius: size * 0.226, style: .continuous)
                .fill(Color(red: 8/255.0, green: 9/255.0, blue: 12/255.0))
                .frame(width: size, height: size)

            // Scaled Concept B Graphic
            GeometryReader { geo in
                let scale = geo.size.width / 512.0

                ZStack {
                    // Top Block (White)
                    Path { path in
                        path.move(to: CGPoint(x: 180 * scale, y: 136 * scale))
                        path.addLine(to: CGPoint(x: 332 * scale, y: 136 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 360 * scale, y: 136 * scale),
                            tangent2End: CGPoint(x: 360 * scale, y: 164 * scale),
                            radius: 24 * scale
                        )
                        path.addLine(to: CGPoint(x: 360 * scale, y: 212 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 360 * scale, y: 240 * scale),
                            tangent2End: CGPoint(x: 332 * scale, y: 240 * scale),
                            radius: 24 * scale
                        )
                        path.addLine(to: CGPoint(x: 236 * scale, y: 240 * scale))
                        path.addLine(to: CGPoint(x: 164 * scale, y: 168 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 156 * scale, y: 160 * scale),
                            tangent2End: CGPoint(x: 180 * scale, y: 136 * scale),
                            radius: 18 * scale
                        )
                        path.closeSubpath()
                    }
                    .fill(Color.white)

                    // Bottom Block (Apple Electric Blue)
                    Path { path in
                        path.move(to: CGPoint(x: 332 * scale, y: 376 * scale))
                        path.addLine(to: CGPoint(x: 180 * scale, y: 376 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 152 * scale, y: 376 * scale),
                            tangent2End: CGPoint(x: 152 * scale, y: 348 * scale),
                            radius: 24 * scale
                        )
                        path.addLine(to: CGPoint(x: 152 * scale, y: 300 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 152 * scale, y: 272 * scale),
                            tangent2End: CGPoint(x: 180 * scale, y: 272 * scale),
                            radius: 24 * scale
                        )
                        path.addLine(to: CGPoint(x: 276 * scale, y: 272 * scale))
                        path.addLine(to: CGPoint(x: 348 * scale, y: 344 * scale))
                        path.addArc(
                            tangent1End: CGPoint(x: 356 * scale, y: 352 * scale),
                            tangent2End: CGPoint(x: 332 * scale, y: 376 * scale),
                            radius: 18 * scale
                        )
                        path.closeSubpath()
                    }
                    .fill(Color(red: 10/255.0, green: 132/255.0, blue: 255/255.0))
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.226, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: size * 0.08, x: 0, y: size * 0.04)
    }
}
