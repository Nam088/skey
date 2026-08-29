import AppKit
import SwiftUI

// MARK: - MainTab Enum with Colored SF Symbol Badges & Localization

public enum MainTab: String, CaseIterable, Identifiable {
    case keyboard
    case clipboard
    case snippets
    case tools
    case ai
    case general
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .keyboard:  return L10n("settings.tab.keyboard")
        case .clipboard: return L10n("settings.tab.clipboard")
        case .snippets:  return L10n("settings.tab.snippets")
        case .tools:     return L10n("settings.tab.tools")
        case .ai:        return L10n("settings.tab.ai")
        case .general:   return L10n("settings.tab.general")
        case .about:     return L10n("settings.tab.about")
        }
    }

    public var icon: String {
        switch self {
        case .keyboard:  return "keyboard.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .snippets:  return "text.quote"
        case .tools:     return "wrench.and.screwdriver.fill"
        case .ai:        return "sparkles"
        case .general:   return "gearshape.fill"
        case .about:     return "info.circle.fill"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .keyboard:  return .blue
        case .clipboard: return .purple
        case .snippets:  return .teal
        case .tools:     return .indigo
        case .ai:        return .pink
        case .general:   return .gray
        case .about:     return .cyan
        }
    }

    public var subtitle: String {
        switch self {
        case .keyboard:  return L10n("settings.tab.keyboard.subtitle")
        case .clipboard: return L10n("settings.tab.clipboard.subtitle")
        case .snippets:  return L10n("settings.tab.snippets.subtitle")
        case .tools:     return L10n("settings.tab.tools.subtitle")
        case .ai:        return L10n("settings.tab.ai.subtitle")
        case .general:   return L10n("settings.tab.general.subtitle")
        case .about:     return L10n("settings.tab.about.subtitle")
        }
    }
}

// MARK: - SettingsDashboardView

public struct SettingsDashboardView: View {
    @ObservedObject var loc = LocalizationService.shared
    @ObservedObject var navState = SettingsNavigationState.shared

    public init() {}

    private var searchResults: [SettingSearchItem] {
        navState.search(query: navState.searchText)
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 14) {
                // Sidebar Header Profile
                sidebarHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 38)

                // Search Bar in Sidebar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField(L10n("settings.search.placeholder"), text: $navState.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    if !navState.searchText.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                navState.searchText = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.quaternaryLabelColor).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 14)

                // Sidebar Navigation Content
                if !navState.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Search Results List
                    if searchResults.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(L10n("clipboard.noMatches"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List(searchResults) { item in
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    navState.navigate(to: item.tab, subTab: item.subTab)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 13))
                                        .foregroundColor(item.tab.badgeColor)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Text(item.tab.title)
                                                .font(.system(size: 10.5, weight: .medium))
                                                .foregroundColor(item.tab.badgeColor)

                                            if !item.subTabTitle.isEmpty {
                                                Text("▸")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                                Text(item.subTabTitle)
                                                    .font(.system(size: 10.5))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.sidebar)
                    }
                } else {
                    // Standard Tab List
                    List(MainTab.allCases, selection: $navState.selectedTab) { tab in
                        NavigationLink(value: tab) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(tab.badgeColor.gradient)
                                        .frame(width: 26, height: 26)

                                    Image(systemName: tab.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                Text(tab.title)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                // Main Header Area (Unified across all tabs)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(navState.selectedTab.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        Text(navState.selectedTab.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                // Detail Content Area (Full-height ScrollView with margin to window edge)
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        Group {
                            switch navState.selectedTab {
                            case .keyboard:
                                KeyboardSettingsTab()
                            case .clipboard:
                                ClipboardSettingsTab()
                            case .snippets:
                                SnippetsSettingsTab()
                            case .tools:
                                ToolsSettingsTab()
                            case .ai:
                                AISettingsTab()
                            case .general:
                                GeneralSettingsTab()
                            case .about:
                                AboutSettingsTab()
                            }
                        }
                        .frame(maxWidth: 520)
                        .toggleStyle(.switch)
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .transition(.opacity.combined(with: .scale(scale: 0.995)))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.automatic)
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: navState.selectedTab)
            }
            .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 520, idealHeight: 580)
    }

    // MARK: - Sidebar Header Profile

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            SKeyLogoView(size: 32)

            Text("SKey")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
