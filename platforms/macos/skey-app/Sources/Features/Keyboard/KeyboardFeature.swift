import AppKit
import Combine
import Foundation

// MARK: - KeyboardFeature

public final class KeyboardFeature: Feature, EventTapManagerDelegate {
    public let id: String = "keyboard"
    public var name: String { L10n(.appTitle) }
    public var isEnabled: Bool { EventTapManager.shared.isListening }

    public var onStatusIconChange: ((Bool) -> Void)?

    private var wasVietnameseBeforeAutoSwitch = false
    private var cancellables = Set<AnyCancellable>()

    // Menu items cache for quick state updates
    private var languageToggleItem: NSMenuItem?
    private var telexItem: NSMenuItem?
    private var simpleTelexItem: NSMenuItem?
    private var vniItem: NSMenuItem?
    private var viqrItem: NSMenuItem?
    private var spellCheckItem: NSMenuItem?
    private var freeMarkingItem: NSMenuItem?
    private var modernStyleItem: NSMenuItem?
    private var smartAppSwitchItem: NSMenuItem?
    private var quickTelexItem: NSMenuItem?
    private var quickStartConsonantItem: NSMenuItem?
    private var quickEndConsonantItem: NSMenuItem?
    private var upperCaseFirstCharItem: NSMenuItem?
    private var swallowedKeyRestoreItem: NSMenuItem?

    public init() {}

    public func start() {
        loadPreferences()
        EventTapManager.shared.delegate = self
        _ = EventTapManager.shared.start()

        AppSettings.shared.shortcuts.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncMenuState()
            }
            .store(in: &cancellables)
    }

    public func stop() {
        EventTapManager.shared.stop()
    }

    public func statusDidChange(isVietnamese: Bool) {
        onStatusIconChange?(isVietnamese)
        syncMenuState()
    }

    // MARK: - App Focus Handling (Smart App Switch)

    public func handleAppFocusChanged(to bundleID: String?) {
        guard AppSettings.shared.keyboard.smartAppSwitchEnabled, let bundleID else { return }

        let isDev = AppFocusObserver.category(for: bundleID) == .developerTool

        if isDev {
            if EventTapManager.shared.isVietnamese {
                wasVietnameseBeforeAutoSwitch = true
                EventTapManager.shared.setLanguage(vietnamese: false)
                skeyLog("Smart Switch: Auto-switched to English for '\(bundleID)'", category: .keyboard)
            }
        } else if wasVietnameseBeforeAutoSwitch {
            EventTapManager.shared.setLanguage(vietnamese: true)
            wasVietnameseBeforeAutoSwitch = false
            skeyLog("Smart Switch: Restored Vietnamese for '\(bundleID)'", category: .keyboard)
        }
    }

    // MARK: - Clean Grouped Menu Builder

    public func buildMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let isVn = EventTapManager.shared.isVietnamese

        // 1. Primary Language Toggle Item
        let langShortcut = AppSettings.shared.shortcuts.languageToggleShortcut
        let toggleItem = NSMenuItem(
            title: "\(L10n("keyboard.menu.vietnamese")) (\(langShortcut.displayString))",
            action: #selector(toggleLanguage),
            keyEquivalent: langShortcut.keyEquivalent
        )
        toggleItem.keyEquivalentModifierMask = langShortcut.keyEquivalentModifierMask
        toggleItem.target = self
        toggleItem.state = isVn ? .on : .off
        languageToggleItem = toggleItem
        items.append(toggleItem)

        // 2. Input Methods Submenu
        let inputMethodMenu = NSMenu()
        telexItem = NSMenuItem(title: "Telex", action: #selector(selectTelex), keyEquivalent: "")
        telexItem?.target = self
        if let item = telexItem { inputMethodMenu.addItem(item) }

        simpleTelexItem = NSMenuItem(title: "Simple Telex", action: #selector(selectSimpleTelex), keyEquivalent: "")
        simpleTelexItem?.target = self
        if let item = simpleTelexItem { inputMethodMenu.addItem(item) }

        vniItem = NSMenuItem(title: "VNI", action: #selector(selectVni), keyEquivalent: "")
        vniItem?.target = self
        if let item = vniItem { inputMethodMenu.addItem(item) }

        viqrItem = NSMenuItem(title: "VIQR", action: #selector(selectViqr), keyEquivalent: "")
        viqrItem?.target = self
        if let item = viqrItem { inputMethodMenu.addItem(item) }

        let imSubmenuItem = NSMenuItem(title: L10n("keyboard.menu.input_method"), action: nil, keyEquivalent: "")
        imSubmenuItem.submenu = inputMethodMenu
        items.append(imSubmenuItem)

        // 3. Character Set Submenu
        let charsetMenu = NSMenu()
        let unicodeItem = NSMenuItem(title: L10n("keyboard.charset.unicode"), action: #selector(selectUnicode), keyEquivalent: "")
        unicodeItem.target = self
        unicodeItem.state = .on
        charsetMenu.addItem(unicodeItem)

        let tcvn3Item = NSMenuItem(title: L10n("keyboard.charset.tcvn3"), action: nil, keyEquivalent: "")
        charsetMenu.addItem(tcvn3Item)

        let vniWinItem = NSMenuItem(title: L10n("keyboard.charset.vni"), action: nil, keyEquivalent: "")
        charsetMenu.addItem(vniWinItem)

        let charsetSubmenuItem = NSMenuItem(title: L10n("keyboard.menu.charset"), action: nil, keyEquivalent: "")
        charsetSubmenuItem.submenu = charsetMenu
        items.append(charsetSubmenuItem)

        // 4. Typing Options Submenu
        let optionsMenu = NSMenu()

        spellCheckItem = NSMenuItem(title: L10n("keyboard.options.spell_check"), action: #selector(toggleSpellCheck), keyEquivalent: "")
        spellCheckItem?.target = self
        if let item = spellCheckItem { optionsMenu.addItem(item) }

        freeMarkingItem = NSMenuItem(title: L10n("keyboard.options.free_marking"), action: #selector(toggleFreeMarking), keyEquivalent: "")
        freeMarkingItem?.target = self
        if let item = freeMarkingItem { optionsMenu.addItem(item) }

        modernStyleItem = NSMenuItem(title: L10n("keyboard.options.modern_style"), action: #selector(toggleModernStyle), keyEquivalent: "")
        modernStyleItem?.target = self
        if let item = modernStyleItem { optionsMenu.addItem(item) }

        swallowedKeyRestoreItem = NSMenuItem(title: L10n("keyboard.advanced.swallowed_restore"), action: #selector(toggleSwallowedKeyRestore), keyEquivalent: "")
        swallowedKeyRestoreItem?.target = self
        if let item = swallowedKeyRestoreItem { optionsMenu.addItem(item) }

        smartAppSwitchItem = NSMenuItem(title: L10n("keyboard.options.smart_switch"), action: #selector(toggleSmartAppSwitch), keyEquivalent: "")
        smartAppSwitchItem?.target = self
        if let item = smartAppSwitchItem { optionsMenu.addItem(item) }

        optionsMenu.addItem(NSMenuItem.separator())

        quickTelexItem = NSMenuItem(title: L10n("keyboard.advanced.quick_telex"), action: #selector(toggleQuickTelex), keyEquivalent: "")
        quickTelexItem?.target = self
        if let item = quickTelexItem { optionsMenu.addItem(item) }

        quickStartConsonantItem = NSMenuItem(title: L10n("keyboard.advanced.quick_start_consonant"), action: #selector(toggleQuickStartConsonant), keyEquivalent: "")
        quickStartConsonantItem?.target = self
        if let item = quickStartConsonantItem { optionsMenu.addItem(item) }

        quickEndConsonantItem = NSMenuItem(title: L10n("keyboard.advanced.quick_end_consonant"), action: #selector(toggleQuickEndConsonant), keyEquivalent: "")
        quickEndConsonantItem?.target = self
        if let item = quickEndConsonantItem { optionsMenu.addItem(item) }

        upperCaseFirstCharItem = NSMenuItem(title: L10n("keyboard.advanced.upper_case_first"), action: #selector(toggleUpperCaseFirstChar), keyEquivalent: "")
        upperCaseFirstCharItem?.target = self
        if let item = upperCaseFirstCharItem { optionsMenu.addItem(item) }

        let optionsSubmenuItem = NSMenuItem(title: L10n("keyboard.menu.typingOptions"), action: nil, keyEquivalent: "")
        optionsSubmenuItem.submenu = optionsMenu
        items.append(optionsSubmenuItem)

        syncMenuState()
        return items
    }

    // MARK: - Preferences & State

    private func loadPreferences() {
        let prefs = AppSettings.shared.keyboard
        let engine = EventTapManager.shared.engine

        EventTapManager.shared.setLanguage(vietnamese: prefs.isVietnamese)

        let method = prefs.inputMethod
        applyInputMethod(method)

        engine.setSpellCheck(prefs.spellCheck)
        engine.setFreeMarking(prefs.freeMarking)
        engine.setModernStyle(prefs.modernStyle)
        engine.setQuickTelex(prefs.quickTelex)
        engine.setQuickStartConsonant(prefs.quickStartConsonant)
        engine.setQuickEndConsonant(prefs.quickEndConsonant)
        engine.setUpperCaseFirstChar(prefs.upperCaseFirstChar)
        engine.setSwallowedKeyRestore(prefs.swallowedKeyRestore)
        engine.setAllowConsonantZFWJ(prefs.allowConsonantZFWJ)
    }

    private func syncMenuState() {
        let prefs = AppSettings.shared.keyboard
        let method = prefs.inputMethod
        let isVn = EventTapManager.shared.isVietnamese

        let langShortcut = AppSettings.shared.shortcuts.languageToggleShortcut
        languageToggleItem?.title = "\(L10n("keyboard.menu.vietnamese")) (\(langShortcut.displayString))"
        languageToggleItem?.keyEquivalent = langShortcut.keyEquivalent
        languageToggleItem?.keyEquivalentModifierMask = langShortcut.keyEquivalentModifierMask
        languageToggleItem?.state = isVn ? .on : .off

        telexItem?.state       = (method == .telex) ? .on : .off
        simpleTelexItem?.state = (method == .simpleTelex) ? .on : .off
        vniItem?.state         = (method == .vni) ? .on : .off
        viqrItem?.state        = (method == .viqr) ? .on : .off

        spellCheckItem?.state  = prefs.spellCheck ? .on : .off
        freeMarkingItem?.state = prefs.freeMarking ? .on : .off
        modernStyleItem?.state = prefs.modernStyle ? .on : .off
        smartAppSwitchItem?.state = prefs.smartAppSwitchEnabled ? .on : .off

        quickTelexItem?.state = prefs.quickTelex ? .on : .off
        quickStartConsonantItem?.state = prefs.quickStartConsonant ? .on : .off
        quickEndConsonantItem?.state = prefs.quickEndConsonant ? .on : .off
        upperCaseFirstCharItem?.state = prefs.upperCaseFirstChar ? .on : .off
        swallowedKeyRestoreItem?.state = prefs.swallowedKeyRestore ? .on : .off
    }

    private func applyInputMethod(_ method: InputMethodType) {
        EventTapManager.shared.engine.setInputMethod(method)
        AppSettings.shared.keyboard.inputMethod = method
        syncMenuState()
    }

    // MARK: - Actions

    @objc public func toggleLanguage() {
        EventTapManager.shared.toggleLanguage()
        AppSettings.shared.keyboard.isVietnamese = EventTapManager.shared.isVietnamese
        syncMenuState()
    }

    @objc private func selectTelex() {
        applyInputMethod(.telex)
    }

    @objc private func selectSimpleTelex() {
        applyInputMethod(.simpleTelex)
    }

    @objc private func selectVni() {
        applyInputMethod(.vni)
    }

    @objc private func selectViqr() {
        applyInputMethod(.viqr)
    }

    @objc private func selectUnicode() {}

    @objc private func toggleSpellCheck() {
        let val = !AppSettings.shared.keyboard.spellCheck
        AppSettings.shared.keyboard.spellCheck = val
        EventTapManager.shared.engine.setSpellCheck(val)
        syncMenuState()
    }

    @objc private func toggleFreeMarking() {
        let val = !AppSettings.shared.keyboard.freeMarking
        AppSettings.shared.keyboard.freeMarking = val
        EventTapManager.shared.engine.setFreeMarking(val)
        syncMenuState()
    }

    @objc private func toggleModernStyle() {
        let val = !AppSettings.shared.keyboard.modernStyle
        AppSettings.shared.keyboard.modernStyle = val
        EventTapManager.shared.engine.setModernStyle(val)
        syncMenuState()
    }

    @objc private func toggleSmartAppSwitch() {
        let val = !AppSettings.shared.keyboard.smartAppSwitchEnabled
        AppSettings.shared.keyboard.smartAppSwitchEnabled = val
        syncMenuState()
    }

    @objc private func toggleQuickTelex() {
        let val = !AppSettings.shared.keyboard.quickTelex
        AppSettings.shared.keyboard.quickTelex = val
        EventTapManager.shared.engine.setQuickTelex(val)
        syncMenuState()
    }

    @objc private func toggleQuickStartConsonant() {
        let val = !AppSettings.shared.keyboard.quickStartConsonant
        AppSettings.shared.keyboard.quickStartConsonant = val
        EventTapManager.shared.engine.setQuickStartConsonant(val)
        syncMenuState()
    }

    @objc private func toggleQuickEndConsonant() {
        let val = !AppSettings.shared.keyboard.quickEndConsonant
        AppSettings.shared.keyboard.quickEndConsonant = val
        EventTapManager.shared.engine.setQuickEndConsonant(val)
        syncMenuState()
    }

    @objc private func toggleUpperCaseFirstChar() {
        let val = !AppSettings.shared.keyboard.upperCaseFirstChar
        AppSettings.shared.keyboard.upperCaseFirstChar = val
        EventTapManager.shared.engine.setUpperCaseFirstChar(val)
        syncMenuState()
    }

    @objc private func toggleSwallowedKeyRestore() {
        let val = !AppSettings.shared.keyboard.swallowedKeyRestore
        AppSettings.shared.keyboard.swallowedKeyRestore = val
        EventTapManager.shared.engine.setSwallowedKeyRestore(val)
        syncMenuState()
    }
}
