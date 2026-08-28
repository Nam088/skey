import Combine
import Foundation
import SwiftUI

// MARK: - SettingSearchItem with SubTab Navigation

public struct SettingSearchItem: Identifiable {
    public let id: String
    public let titleKey: String
    public let subtitleKey: String
    public let tab: MainTab
    public let subTab: Int
    public let subTabTitleKey: String
    public let icon: String
    public let keywordsKey: String

    public init(
        id: String,
        titleKey: String,
        subtitleKey: String,
        tab: MainTab,
        subTab: Int,
        subTabTitleKey: String,
        icon: String,
        keywordsKey: String
    ) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.tab = tab
        self.subTab = subTab
        self.subTabTitleKey = subTabTitleKey
        self.icon = icon
        self.keywordsKey = keywordsKey
    }

    public var title: String {
        L10n(titleKey)
    }

    public var subtitle: String {
        L10n(subtitleKey)
    }

    public var subTabTitle: String {
        L10n(subTabTitleKey)
    }

    public var keywords: [String] {
        L10n(keywordsKey).components(separatedBy: ",")
    }
}

// MARK: - SettingsNavigationState

public final class SettingsNavigationState: ObservableObject {
    public static let shared = SettingsNavigationState()

    @Published public var selectedTab: MainTab = .keyboard
    @Published public var keyboardSubTab: Int = 0
    @Published public var clipboardSubTab: Int = 0
    @Published public var snippetsSubTab: Int = 0
    @Published public var toolsSubTab: Int = 0
    @Published public var aiSubTab: Int = 0
    @Published public var generalSubTab: Int = 0

    @Published public var searchText: String = ""

    private init() {}

    public func navigate(to tab: MainTab, subTab: Int = 0) {
        self.selectedTab = tab
        switch tab {
        case .keyboard:
            self.keyboardSubTab = subTab
        case .clipboard:
            self.clipboardSubTab = subTab
        case .snippets:
            self.snippetsSubTab = subTab
        case .tools:
            self.toolsSubTab = subTab
        case .ai:
            self.aiSubTab = subTab
        case .general:
            self.generalSubTab = subTab
        case .about:
            break
        }
        self.searchText = ""
    }

    public var allSearchItems: [SettingSearchItem] {
        [
            // MARK: 1. Keyboard (Tab 0)
            // SubTab 0: Kiểu gõ (Input Method)
            SettingSearchItem(
                id: "kb_input_method",
                titleKey: "keyboard.option.primaryMethod",
                subtitleKey: "search.item.kb_input_method.sub",
                tab: .keyboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.inputMethod",
                icon: "keyboard.fill",
                keywordsKey: "search.item.kb_input_method.keys"
            ),
            SettingSearchItem(
                id: "kb_charset",
                titleKey: "keyboard.option.charset",
                subtitleKey: "search.item.kb_charset.sub",
                tab: .keyboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.inputMethod",
                icon: "character.book.closed.fill",
                keywordsKey: "search.item.kb_charset.keys"
            ),
            SettingSearchItem(
                id: "kb_toggle_vn",
                titleKey: "keyboard.option.enableVietnamese",
                subtitleKey: "search.item.kb_toggle_vn.sub",
                tab: .keyboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.inputMethod",
                icon: "globe",
                keywordsKey: "search.item.kb_toggle_vn.keys"
            ),
            SettingSearchItem(
                id: "kb_shortcut_toggle",
                titleKey: "keyboard.shortcut.toggleTitle",
                subtitleKey: "search.item.kb_shortcut_toggle.sub",
                tab: .keyboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.inputMethod",
                icon: "command.circle.fill",
                keywordsKey: "search.item.kb_shortcut_toggle.keys"
            ),

            // SubTab 1: Quy tắc gõ & Gõ nhanh (Typing Rules)
            SettingSearchItem(
                id: "kb_spell_check",
                titleKey: "keyboard.options.spell_check",
                subtitleKey: "search.item.kb_spell_check.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "checkmark.bubble.fill",
                keywordsKey: "search.item.kb_spell_check.keys"
            ),
            SettingSearchItem(
                id: "kb_free_marking",
                titleKey: "keyboard.options.free_marking",
                subtitleKey: "search.item.kb_free_marking.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "character.cursor.ibeam",
                keywordsKey: "search.item.kb_free_marking.keys"
            ),
            SettingSearchItem(
                id: "kb_modern_style",
                titleKey: "keyboard.options.modern_style",
                subtitleKey: "search.item.kb_modern_style.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "textformat.abc.dottedunderline",
                keywordsKey: "search.item.kb_modern_style.keys"
            ),
            SettingSearchItem(
                id: "kb_swallowed",
                titleKey: "keyboard.advanced.swallowed_restore",
                subtitleKey: "search.item.kb_swallowed.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "arrow.counterclockwise.circle.fill",
                keywordsKey: "search.item.kb_swallowed.keys"
            ),
            SettingSearchItem(
                id: "kb_quick_telex",
                titleKey: "keyboard.advanced.quick_telex",
                subtitleKey: "search.item.kb_quick_telex.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "bolt.fill",
                keywordsKey: "search.item.kb_quick_telex.keys"
            ),
            SettingSearchItem(
                id: "kb_quick_start",
                titleKey: "keyboard.option.quickStartConsonant",
                subtitleKey: "search.item.kb_quick_start.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "character.textbox",
                keywordsKey: "search.item.kb_quick_start.keys"
            ),
            SettingSearchItem(
                id: "kb_quick_end",
                titleKey: "keyboard.option.quickEndConsonant",
                subtitleKey: "search.item.kb_quick_end.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "character.textbox",
                keywordsKey: "search.item.kb_quick_end.keys"
            ),
            SettingSearchItem(
                id: "kb_upper_first",
                titleKey: "keyboard.option.upperCaseFirst",
                subtitleKey: "search.item.kb_upper_first.sub",
                tab: .keyboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.typingRules",
                icon: "textformat.size",
                keywordsKey: "search.item.kb_upper_first.keys"
            ),

            // SubTab 2: Quản lý Ứng dụng (Smart Switch & Excluded Apps)
            SettingSearchItem(
                id: "kb_smart_switch",
                titleKey: "keyboard.option.smartSwitch",
                subtitleKey: "search.item.kb_smart_switch.sub",
                tab: .keyboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appManagement",
                icon: "terminal.fill",
                keywordsKey: "search.item.kb_smart_switch.keys"
            ),
            SettingSearchItem(
                id: "kb_excluded_apps",
                titleKey: "keyboard.section.excludedApps",
                subtitleKey: "search.item.kb_excluded_apps.sub",
                tab: .keyboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appManagement",
                icon: "xmark.app.fill",
                keywordsKey: "search.item.kb_excluded_apps.keys"
            ),

            // MARK: 2. Clipboard (Tab 1)
            // SubTab 0: Chung
            SettingSearchItem(
                id: "cb_monitor",
                titleKey: "clipboard.option.enableMonitor",
                subtitleKey: "search.item.cb_monitor.sub",
                tab: .clipboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.general",
                icon: "doc.on.clipboard.fill",
                keywordsKey: "search.item.cb_monitor.keys"
            ),
            SettingSearchItem(
                id: "cb_shortcut",
                titleKey: "clipboard.option.shortcut",
                subtitleKey: "search.item.cb_shortcut.sub",
                tab: .clipboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.general",
                icon: "command.circle.fill",
                keywordsKey: "search.item.cb_shortcut.keys"
            ),
            SettingSearchItem(
                id: "cb_search_mode",
                titleKey: "clipboard.option.searchType",
                subtitleKey: "search.item.cb_search_mode.sub",
                tab: .clipboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.general",
                icon: "magnifyingglass",
                keywordsKey: "search.item.cb_search_mode.keys"
            ),
            SettingSearchItem(
                id: "cb_auto_paste",
                titleKey: "clipboard.option.autoPaste",
                subtitleKey: "search.item.cb_auto_paste.sub",
                tab: .clipboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.general",
                icon: "arrow.right.doc.on.clipboard",
                keywordsKey: "search.item.cb_auto_paste.keys"
            ),
            SettingSearchItem(
                id: "cb_plain_text",
                titleKey: "clipboard.option.plainText",
                subtitleKey: "search.item.cb_plain_text.sub",
                tab: .clipboard,
                subTab: 0,
                subTabTitleKey: "settings.subtab.general",
                icon: "text.alignleft",
                keywordsKey: "search.item.cb_plain_text.keys"
            ),

            // SubTab 1: Lưu trữ (Storage)
            SettingSearchItem(
                id: "cb_save_text",
                titleKey: "clipboard.option.saveText",
                subtitleKey: "search.item.cb_save_text.sub",
                tab: .clipboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.storage",
                icon: "doc.text.fill",
                keywordsKey: "search.item.cb_save_text.keys"
            ),
            SettingSearchItem(
                id: "cb_images",
                titleKey: "clipboard.option.saveImages",
                subtitleKey: "search.item.cb_images.sub",
                tab: .clipboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.storage",
                icon: "photo.fill",
                keywordsKey: "search.item.cb_images.keys"
            ),
            SettingSearchItem(
                id: "cb_history_limit",
                titleKey: "clipboard.option.maxItems",
                subtitleKey: "search.item.cb_history_limit.sub",
                tab: .clipboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.storage",
                icon: "list.number",
                keywordsKey: "search.item.cb_history_limit.keys"
            ),
            SettingSearchItem(
                id: "cb_sort_order",
                titleKey: "clipboard.option.sortOrder",
                subtitleKey: "search.item.cb_sort_order.sub",
                tab: .clipboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.storage",
                icon: "arrow.up.arrow.down",
                keywordsKey: "search.item.cb_sort_order.keys"
            ),
            SettingSearchItem(
                id: "cb_clear_all",
                titleKey: "clipboard.action.clearAll",
                subtitleKey: "search.item.cb_clear_all.sub",
                tab: .clipboard,
                subTab: 1,
                subTabTitleKey: "settings.subtab.storage",
                icon: "trash.fill",
                keywordsKey: "search.item.cb_clear_all.keys"
            ),

            // SubTab 2: Giao diện (Appearance)
            SettingSearchItem(
                id: "cb_popup_pos",
                titleKey: "clipboard.option.popupPosition",
                subtitleKey: "search.item.cb_popup_pos.sub",
                tab: .clipboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appearance",
                icon: "macwindow",
                keywordsKey: "search.item.cb_popup_pos.keys"
            ),
            SettingSearchItem(
                id: "cb_pin_loc",
                titleKey: "clipboard.option.pinLocation",
                subtitleKey: "search.item.cb_pin_loc.sub",
                tab: .clipboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appearance",
                icon: "pin.fill",
                keywordsKey: "search.item.cb_pin_loc.keys"
            ),
            SettingSearchItem(
                id: "cb_hover_preview",
                titleKey: "clipboard.option.hoverPreview",
                subtitleKey: "search.item.cb_hover_preview.sub",
                tab: .clipboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appearance",
                icon: "eye.fill",
                keywordsKey: "search.item.cb_hover_preview.keys"
            ),
            SettingSearchItem(
                id: "cb_app_icons",
                titleKey: "clipboard.option.appIcons",
                subtitleKey: "search.item.cb_app_icons.sub",
                tab: .clipboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appearance",
                icon: "app.badge.fill",
                keywordsKey: "search.item.cb_app_icons.keys"
            ),
            SettingSearchItem(
                id: "cb_color_swatch",
                titleKey: "clipboard.option.colorSwatch",
                subtitleKey: "search.item.cb_color_swatch.sub",
                tab: .clipboard,
                subTab: 2,
                subTabTitleKey: "settings.subtab.appearance",
                icon: "paintpalette.fill",
                keywordsKey: "search.item.cb_color_swatch.keys"
            ),

            // SubTab 3: Mục đã ghim (Pins)
            SettingSearchItem(
                id: "cb_pins",
                titleKey: "clipboard.section.pinsTitle",
                subtitleKey: "search.item.cb_pins.sub",
                tab: .clipboard,
                subTab: 3,
                subTabTitleKey: "settings.subtab.pins",
                icon: "pin.circle.fill",
                keywordsKey: "search.item.cb_pins.keys"
            ),

            // SubTab 4: Bảo mật (Privacy)
            SettingSearchItem(
                id: "cb_privacy",
                titleKey: "clipboard.section.privacy",
                subtitleKey: "search.item.cb_privacy.sub",
                tab: .clipboard,
                subTab: 4,
                subTabTitleKey: "settings.subtab.privacy",
                icon: "lock.shield.fill",
                keywordsKey: "search.item.cb_privacy.keys"
            ),

            // MARK: 3. Gõ tắt (Snippets - Tab 2)
            // SubTab 0: Bảng gõ tắt
            SettingSearchItem(
                id: "macro_enable",
                titleKey: "macro.option.enable",
                subtitleKey: "search.item.macro_enable.sub",
                tab: .snippets,
                subTab: 0,
                subTabTitleKey: "settings.subtab.snippetsList",
                icon: "text.quote",
                keywordsKey: "search.item.macro_enable.keys"
            ),
            SettingSearchItem(
                id: "macro_auto_caps",
                titleKey: "macro.option.autoCaps",
                subtitleKey: "search.item.macro_auto_caps.sub",
                tab: .snippets,
                subTab: 0,
                subTabTitleKey: "settings.subtab.snippetsList",
                icon: "textformat.size",
                keywordsKey: "search.item.macro_auto_caps.keys"
            ),
            SettingSearchItem(
                id: "macro_in_english",
                titleKey: "macro.option.inEnglish",
                subtitleKey: "search.item.macro_in_english.sub",
                tab: .snippets,
                subTab: 0,
                subTabTitleKey: "settings.subtab.snippetsList",
                icon: "character.textbox",
                keywordsKey: "search.item.macro_in_english.keys"
            ),
            SettingSearchItem(
                id: "macro_add_new",
                titleKey: "macro.section.add",
                subtitleKey: "search.item.macro_add_new.sub",
                tab: .snippets,
                subTab: 0,
                subTabTitleKey: "settings.subtab.snippetsList",
                icon: "plus.circle.fill",
                keywordsKey: "search.item.macro_add_new.keys"
            ),

            // SubTab 1: Sao lưu (Backup)
            SettingSearchItem(
                id: "macro_backup",
                titleKey: "macro.section.backup",
                subtitleKey: "search.item.macro_backup.sub",
                tab: .snippets,
                subTab: 1,
                subTabTitleKey: "settings.subtab.backup",
                icon: "arrow.up.doc.fill",
                keywordsKey: "search.item.macro_backup.keys"
            ),

            // MARK: 4. Công cụ (Tools - Tab 3)
            // SubTab 0: Dịch nhanh
            SettingSearchItem(
                id: "tool_translator",
                titleKey: "tools.translator.title",
                subtitleKey: "tools.translator.shortcutDesc",
                tab: .tools,
                subTab: 0,
                subTabTitleKey: "settings.subtab.translator",
                icon: "globe.asia.australia.fill",
                keywordsKey: "tools.translator.shortcut"
            ),
            // SubTab 1: Vệ sinh phím
            SettingSearchItem(
                id: "tool_cleaner",
                titleKey: "cleaner.title",
                subtitleKey: "search.item.tool_cleaner.sub",
                tab: .tools,
                subTab: 1,
                subTabTitleKey: "settings.subtab.utilities",
                icon: "sparkles",
                keywordsKey: "search.item.tool_cleaner.keys"
            ),
            SettingSearchItem(
                id: "tool_cleaner_shortcut",
                titleKey: "cleaner.option.shortcut",
                subtitleKey: "search.item.tool_cleaner_shortcut.sub",
                tab: .tools,
                subTab: 1,
                subTabTitleKey: "settings.subtab.utilities",
                icon: "command.circle.fill",
                keywordsKey: "search.item.tool_cleaner_shortcut.keys"
            ),
            // SubTab 2: Chuyển mã văn bản
            SettingSearchItem(
                id: "tool_converter",
                titleKey: "tools.section.converter",
                subtitleKey: "search.item.tool_converter.sub",
                tab: .tools,
                subTab: 2,
                subTabTitleKey: "settings.subtab.textConverter",
                icon: "character.textbox",
                keywordsKey: "search.item.tool_converter.keys"
            ),

            // MARK: 5. Trợ lý AI (Tab 4)
            // SubTab 0: Mô hình AI
            SettingSearchItem(
                id: "ai_provider",
                titleKey: "ai.section.provider",
                subtitleKey: "search.item.ai_provider.sub",
                tab: .ai,
                subTab: 0,
                subTabTitleKey: "settings.subtab.aiModel",
                icon: "cpu.fill",
                keywordsKey: "search.item.ai_provider.keys"
            ),
            // SubTab 1: Mẫu câu lệnh
            SettingSearchItem(
                id: "ai_prompts",
                titleKey: "ai.section.prompts",
                subtitleKey: "search.item.ai_prompts.sub",
                tab: .ai,
                subTab: 1,
                subTabTitleKey: "settings.subtab.aiPrompts",
                icon: "text.bubble.fill",
                keywordsKey: "search.item.ai_prompts.keys"
            ),
            // SubTab 2: Phím tắt
            SettingSearchItem(
                id: "ai_shortcuts",
                titleKey: "ai.section.shortcuts",
                subtitleKey: "search.item.ai_shortcuts.sub",
                tab: .ai,
                subTab: 2,
                subTabTitleKey: "settings.subtab.aiShortcuts",
                icon: "command",
                keywordsKey: "search.item.ai_shortcuts.keys"
            ),

            // MARK: 5. Cài đặt chung (General - Tab 4)
            // SubTab 0: Cơ bản
            SettingSearchItem(
                id: "gen_launch_at_login",
                titleKey: "general.option.launchAtLogin",
                subtitleKey: "search.item.gen_launch_at_login.sub",
                tab: .general,
                subTab: 0,
                subTabTitleKey: "settings.subtab.basic",
                icon: "power.circle.fill",
                keywordsKey: "search.item.gen_launch_at_login.keys"
            ),
            SettingSearchItem(
                id: "gen_language",
                titleKey: "general.option.appLanguage",
                subtitleKey: "search.item.gen_language.sub",
                tab: .general,
                subTab: 0,
                subTabTitleKey: "settings.subtab.basic",
                icon: "character.bubble.fill",
                keywordsKey: "search.item.gen_language.keys"
            ),
            SettingSearchItem(
                id: "gen_check_updates",
                titleKey: "general.option.checkUpdates",
                subtitleKey: "search.item.gen_check_updates.sub",
                tab: .general,
                subTab: 0,
                subTabTitleKey: "settings.subtab.basic",
                icon: "arrow.triangle.2.circlepath",
                keywordsKey: "search.item.gen_check_updates.keys"
            ),

            // SubTab 1: Quyền hệ thống
            SettingSearchItem(
                id: "gen_permissions",
                titleKey: "general.section.permissions",
                subtitleKey: "search.item.gen_permissions.sub",
                tab: .general,
                subTab: 1,
                subTabTitleKey: "settings.subtab.permissions",
                icon: "lock.shield.fill",
                keywordsKey: "search.item.gen_permissions.keys"
            ),

            // SubTab 2: Nhật ký & Dữ liệu
            SettingSearchItem(
                id: "gen_debug_mode",
                titleKey: "general.option.debugMode",
                subtitleKey: "search.item.gen_debug_mode.sub",
                tab: .general,
                subTab: 2,
                subTabTitleKey: "settings.subtab.logs",
                icon: "ant.fill",
                keywordsKey: "search.item.gen_debug_mode.keys"
            ),
            SettingSearchItem(
                id: "gen_logs",
                titleKey: "general.section.logs",
                subtitleKey: "search.item.gen_logs.sub",
                tab: .general,
                subTab: 2,
                subTabTitleKey: "settings.subtab.logs",
                icon: "doc.text.magnifyingglass",
                keywordsKey: "search.item.gen_logs.keys"
            ),
            SettingSearchItem(
                id: "gen_export_settings",
                titleKey: "general.option.exportSettings",
                subtitleKey: "search.item.gen_export_settings.sub",
                tab: .general,
                subTab: 2,
                subTabTitleKey: "settings.subtab.logs",
                icon: "square.and.arrow.up.fill",
                keywordsKey: "search.item.gen_export_settings.keys"
            ),
            SettingSearchItem(
                id: "gen_import_settings",
                titleKey: "general.option.importSettings",
                subtitleKey: "search.item.gen_import_settings.sub",
                tab: .general,
                subTab: 2,
                subTabTitleKey: "settings.subtab.logs",
                icon: "square.and.arrow.down.fill",
                keywordsKey: "search.item.gen_import_settings.keys"
            ),
            SettingSearchItem(
                id: "gen_reset",
                titleKey: "general.action.resetDefaults",
                subtitleKey: "search.item.gen_reset.sub",
                tab: .general,
                subTab: 2,
                subTabTitleKey: "settings.subtab.logs",
                icon: "arrow.counterclockwise",
                keywordsKey: "search.item.gen_reset.keys"
            ),

            // MARK: 6. Giới thiệu (About - Tab 5)
            SettingSearchItem(
                id: "about_info",
                titleKey: "about.title",
                subtitleKey: "search.item.about_info.sub",
                tab: .about,
                subTab: 0,
                subTabTitleKey: "settings.tab.about",
                icon: "info.circle.fill",
                keywordsKey: "search.item.about_info.keys"
            )
        ]
    }

    public func search(query: String) -> [SettingSearchItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }

        return allSearchItems.filter { item in
            item.title.lowercased().contains(q) ||
            item.subtitle.lowercased().contains(q) ||
            item.tab.title.lowercased().contains(q) ||
            item.subTabTitle.lowercased().contains(q) ||
            item.keywords.contains { $0.trimmingCharacters(in: .whitespaces).lowercased().contains(q) }
        }
    }
}
