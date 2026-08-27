import AppKit
import Foundation

// MARK: - KeyboardFeature

/// Feature module providing Vietnamese IME typing (Telex, VNI, VIQR, etc.)
public final class KeyboardFeature: NSObject, Feature, EventTapManagerDelegate {
    public let id = "com.nam088.skey.feature.keyboard"
    public var name: String { L10n(.inputMethodMenu) }

    public var isEnabled: Bool = true

    // UI Menu items
    private var telexItem: NSMenuItem!
    private var simpleTelexItem: NSMenuItem!
    private var vniItem: NSMenuItem!
    private var viqrItem: NSMenuItem!

    private var spellCheckItem: NSMenuItem!
    private var freeMarkingItem: NSMenuItem!
    private var modernStyleItem: NSMenuItem!
    private var smartAppSwitchItem: NSMenuItem!
    private var wasVietnameseBeforeAutoSwitch: Bool = false

    // Advanced Items
    private var quickTelexItem: NSMenuItem!
    private var quickStartConsonantItem: NSMenuItem!
    private var quickEndConsonantItem: NSMenuItem!
    private var upperCaseFirstCharItem: NSMenuItem!
    private var swallowedKeyRestoreItem: NSMenuItem!

    public var onStatusIconChange: ((Bool) -> Void)?

    public override init() {
        super.init()
        EventTapManager.shared.delegate = self
    }

    // MARK: - Lifecycle

    public func start() {
        loadPreferences()
        if PermissionsService.shared.checkPermissions(prompt: false) {
            _ = EventTapManager.shared.start()
        }
    }

    public func stop() {
        EventTapManager.shared.stop()
    }

    public func resetBuffer() {
        EventTapManager.shared.engine.reset()
    }

    /// Handles application focus changes: resets composing buffer and performs Smart App Switching
    public func handleAppFocusChanged(to bundleID: String?) {
        resetBuffer()

        guard PreferencesService.shared.smartAppSwitchEnabled, let bundleID else { return }

        let developerApps: Set<String> = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.sublimetext.4",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.jetbrains.webstorm",
            "com.jetbrains.goland",
            "com.jetbrains.rider",
            "com.jetbrains.clion",
            "com.mitchellh.ghostty",
            "co.zeit.hyper",
            "net.kovidgoyal.kitty",
            "org.alacritty"
        ]

        if developerApps.contains(bundleID) {
            if EventTapManager.shared.isVietnamese {
                wasVietnameseBeforeAutoSwitch = true
                EventTapManager.shared.setLanguage(vietnamese: false)
                skeyLog("Smart Switch: Auto-switched to English for '\(bundleID)'", category: .keyboard)
            }
        } else if wasVietnameseBeforeAutoSwitch {
            // Restore Vietnamese when returning to browser, chat, notes, etc.
            EventTapManager.shared.setLanguage(vietnamese: true)
            wasVietnameseBeforeAutoSwitch = false
            skeyLog("Smart Switch: Restored Vietnamese for '\(bundleID)'", category: .keyboard)
        }
    }

    // MARK: - Menu Builder

    public func buildMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        // Language toggle item
        let toggleItem = NSMenuItem(
            title: L10n(.toggleLanguage),
            action: #selector(toggleLanguage),
            keyEquivalent: "z"
        )
        toggleItem.keyEquivalentModifierMask = .option
        toggleItem.target = self
        items.append(toggleItem)

        // Input methods submenu
        let inputMethodMenu = NSMenu()
        telexItem = NSMenuItem(title: "Telex", action: #selector(selectTelex), keyEquivalent: "")
        telexItem.target = self
        inputMethodMenu.addItem(telexItem)

        simpleTelexItem = NSMenuItem(title: "Simple Telex", action: #selector(selectSimpleTelex), keyEquivalent: "")
        simpleTelexItem.target = self
        inputMethodMenu.addItem(simpleTelexItem)

        vniItem = NSMenuItem(title: "VNI", action: #selector(selectVni), keyEquivalent: "")
        vniItem.target = self
        inputMethodMenu.addItem(vniItem)

        viqrItem = NSMenuItem(title: "VIQR", action: #selector(selectViqr), keyEquivalent: "")
        viqrItem.target = self
        inputMethodMenu.addItem(viqrItem)

        let imSubmenuItem = NSMenuItem(title: L10n(.inputMethodMenu), action: nil, keyEquivalent: "")
        imSubmenuItem.submenu = inputMethodMenu
        items.append(imSubmenuItem)

        // Standard Options
        spellCheckItem = NSMenuItem(title: L10n(.spellCheck), action: #selector(toggleSpellCheck), keyEquivalent: "")
        spellCheckItem.target = self
        items.append(spellCheckItem)

        freeMarkingItem = NSMenuItem(title: L10n(.freeMarking), action: #selector(toggleFreeMarking), keyEquivalent: "")
        freeMarkingItem.target = self
        items.append(freeMarkingItem)

        modernStyleItem = NSMenuItem(title: L10n(.modernStyle), action: #selector(toggleModernStyle), keyEquivalent: "")
        modernStyleItem.target = self
        items.append(modernStyleItem)

        smartAppSwitchItem = NSMenuItem(title: L10n(.smartAppSwitch), action: #selector(toggleSmartAppSwitch), keyEquivalent: "")
        smartAppSwitchItem.target = self
        items.append(smartAppSwitchItem)

        // Advanced Options Submenu
        let advancedMenu = NSMenu()

        quickTelexItem = NSMenuItem(title: L10n(.quickTelex), action: #selector(toggleQuickTelex), keyEquivalent: "")
        quickTelexItem.target = self
        advancedMenu.addItem(quickTelexItem)

        quickStartConsonantItem = NSMenuItem(title: L10n(.quickStartConsonant), action: #selector(toggleQuickStartConsonant), keyEquivalent: "")
        quickStartConsonantItem.target = self
        advancedMenu.addItem(quickStartConsonantItem)

        quickEndConsonantItem = NSMenuItem(title: L10n(.quickEndConsonant), action: #selector(toggleQuickEndConsonant), keyEquivalent: "")
        quickEndConsonantItem.target = self
        advancedMenu.addItem(quickEndConsonantItem)

        upperCaseFirstCharItem = NSMenuItem(title: L10n(.upperCaseFirstChar), action: #selector(toggleUpperCaseFirstChar), keyEquivalent: "")
        upperCaseFirstCharItem.target = self
        advancedMenu.addItem(upperCaseFirstCharItem)

        swallowedKeyRestoreItem = NSMenuItem(title: L10n(.swallowedKeyRestore), action: #selector(toggleSwallowedKeyRestore), keyEquivalent: "")
        swallowedKeyRestoreItem.target = self
        advancedMenu.addItem(swallowedKeyRestoreItem)

        let advSubmenuItem = NSMenuItem(title: L10n(.advancedOptions), action: nil, keyEquivalent: "")
        advSubmenuItem.submenu = advancedMenu
        items.append(advSubmenuItem)

        // Sync initial checked states
        syncMenuState()

        return items
    }

    // MARK: - Preferences & State

    private func loadPreferences() {
        let prefs = PreferencesService.shared
        let engine = EventTapManager.shared.engine

        // Language
        EventTapManager.shared.setLanguage(vietnamese: prefs.isVietnamese)

        // Input Method
        let method = InputMethodType(rawValue: prefs.inputMethodRawValue) ?? .telex
        applyInputMethod(method)

        // Options
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
        guard telexItem != nil else { return }
        let prefs = PreferencesService.shared
        let method = InputMethodType(rawValue: prefs.inputMethodRawValue) ?? .telex

        telexItem.state       = (method == .telex) ? .on : .off
        simpleTelexItem.state = (method == .simpleTelex) ? .on : .off
        vniItem.state         = (method == .vni) ? .on : .off
        viqrItem.state        = (method == .viqr) ? .on : .off

        spellCheckItem.state  = prefs.spellCheck ? .on : .off
        freeMarkingItem.state = prefs.freeMarking ? .on : .off
        modernStyleItem?.state        = prefs.modernStyle ? .on : .off
        smartAppSwitchItem?.state     = prefs.smartAppSwitchEnabled ? .on : .off

        quickTelexItem?.state = prefs.quickTelex ? .on : .off
        quickStartConsonantItem?.state = prefs.quickStartConsonant ? .on : .off
        quickEndConsonantItem?.state = prefs.quickEndConsonant ? .on : .off
        upperCaseFirstCharItem?.state = prefs.upperCaseFirstChar ? .on : .off
        swallowedKeyRestoreItem?.state = prefs.swallowedKeyRestore ? .on : .off
    }

    private func applyInputMethod(_ method: InputMethodType) {
        EventTapManager.shared.engine.setInputMethod(method)
        PreferencesService.shared.inputMethodRawValue = method.rawValue
        syncMenuState()
    }

    // MARK: - Actions

    @objc public func toggleLanguage() {
        EventTapManager.shared.toggleLanguage()
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

    @objc private func toggleSpellCheck() {
        let newState = !PreferencesService.shared.spellCheck
        PreferencesService.shared.spellCheck = newState
        EventTapManager.shared.engine.setSpellCheck(newState)
        syncMenuState()
    }

    @objc private func toggleFreeMarking() {
        let newState = !PreferencesService.shared.freeMarking
        PreferencesService.shared.freeMarking = newState
        EventTapManager.shared.engine.setFreeMarking(newState)
        syncMenuState()
    }

    @objc private func toggleModernStyle() {
        let newState = !PreferencesService.shared.modernStyle
        PreferencesService.shared.modernStyle = newState
        EventTapManager.shared.engine.setModernStyle(newState)
        syncMenuState()
    }

    @objc private func toggleSmartAppSwitch() {
        let newState = !PreferencesService.shared.smartAppSwitchEnabled
        PreferencesService.shared.smartAppSwitchEnabled = newState
        syncMenuState()
        skeyLog("Smart App Switch: \(newState ? "Enabled" : "Disabled")", category: .keyboard)
    }

    @objc private func toggleQuickTelex() {
        let newState = !PreferencesService.shared.quickTelex
        PreferencesService.shared.quickTelex = newState
        EventTapManager.shared.engine.setQuickTelex(newState)
        syncMenuState()
    }

    @objc private func toggleQuickStartConsonant() {
        let newState = !PreferencesService.shared.quickStartConsonant
        PreferencesService.shared.quickStartConsonant = newState
        EventTapManager.shared.engine.setQuickStartConsonant(newState)
        syncMenuState()
    }

    @objc private func toggleQuickEndConsonant() {
        let newState = !PreferencesService.shared.quickEndConsonant
        PreferencesService.shared.quickEndConsonant = newState
        EventTapManager.shared.engine.setQuickEndConsonant(newState)
        syncMenuState()
    }

    @objc private func toggleUpperCaseFirstChar() {
        let newState = !PreferencesService.shared.upperCaseFirstChar
        PreferencesService.shared.upperCaseFirstChar = newState
        EventTapManager.shared.engine.setUpperCaseFirstChar(newState)
        syncMenuState()
    }

    @objc private func toggleSwallowedKeyRestore() {
        let newState = !PreferencesService.shared.swallowedKeyRestore
        PreferencesService.shared.swallowedKeyRestore = newState
        EventTapManager.shared.engine.setSwallowedKeyRestore(newState)
        syncMenuState()
    }

    // MARK: - EventTapManagerDelegate

    public func statusDidChange(isVietnamese: Bool) {
        onStatusIconChange?(isVietnamese)
    }
}
