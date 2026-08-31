import AppKit
import Carbon
import CoreGraphics
import Foundation

// MARK: - ShortcutModifiers OptionSet

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let option  = ShortcutModifiers(rawValue: 1 << 1)
    public static let control = ShortcutModifiers(rawValue: 1 << 2)
    public static let shift   = ShortcutModifiers(rawValue: 1 << 3)

    public init(cgFlags: CGEventFlags) {
        var mods: ShortcutModifiers = []
        if cgFlags.contains(.maskCommand) { mods.insert(.command) }
        if cgFlags.contains(.maskAlternate) { mods.insert(.option) }
        if cgFlags.contains(.maskControl) { mods.insert(.control) }
        if cgFlags.contains(.maskShift) { mods.insert(.shift) }
        self = mods
    }

    public init(nsFlags: NSEvent.ModifierFlags) {
        var mods: ShortcutModifiers = []
        if nsFlags.contains(.command) { mods.insert(.command) }
        if nsFlags.contains(.option) { mods.insert(.option) }
        if nsFlags.contains(.control) { mods.insert(.control) }
        if nsFlags.contains(.shift) { mods.insert(.shift) }
        self = mods
    }

    public var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }

    public var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option)  { result += "⌥" }
        if contains(.shift)   { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    public var symbolList: [String] {
        var list: [String] = []
        if contains(.control) { list.append("⌃") }
        if contains(.option)  { list.append("⌥") }
        if contains(.shift)   { list.append("⇧") }
        if contains(.command) { list.append("⌘") }
        return list
    }
}

// MARK: - KeyShortcut Model

public struct KeyShortcut: Codable, Equatable, Hashable, Sendable {
    /// Virtual key code (nil for modifier-only shortcuts like Control+Shift)
    public var keyCode: UInt16?
    /// Modifier bitmask
    public var modifiers: ShortcutModifiers

    public var isModifierOnly: Bool {
        keyCode == nil
    }

    public init(keyCode: UInt16?, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(keyCode: UInt16?, nsModifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = ShortcutModifiers(nsFlags: nsModifiers)
    }

    public init(keyCode: UInt16?, cgModifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = ShortcutModifiers(cgFlags: cgModifiers)
    }

    // MARK: - Standard Built-in Presets

    public static let optionZ = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_Z), modifiers: .option)
    public static let ctrlShift = KeyShortcut(keyCode: nil, modifiers: [.control, .shift])
    public static let ctrlOptionZ = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_Z), modifiers: [.control, .option])
    public static let cmdShift = KeyShortcut(keyCode: nil, modifiers: [.command, .shift])
    public static let optionShift = KeyShortcut(keyCode: nil, modifiers: [.option, .shift])
    public static let ctrlSpace = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_Space), modifiers: .control)

    public static let optionV = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_V), modifiers: .option)
    public static let cmdShiftV = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_V), modifiers: [.command, .shift])
    public static let ctrlOptionV = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_V), modifiers: [.control, .option])
    public static let optionC = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_C), modifiers: .option)

    public static let optionShiftK = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_K), modifiers: [.option, .shift])
    public static let optionShiftC = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_C), modifiers: [.option, .shift])
    public static let ctrlOptionK = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_K), modifiers: [.control, .option])

    public static let optionSpace = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_Space), modifiers: .option)
    public static let ctrlOptionSpace = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_Space), modifiers: [.control, .option])
    public static let cmdShiftSpace = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_Space), modifiers: [.command, .shift])

    // MARK: - Display String & KeyCap Badges

    public var displayString: String {
        if isModifierOnly {
            return modifiers.symbols
        }
        guard let code = keyCode else { return modifiers.symbols }
        let keyName = KeyCodeHelper.string(for: code)
        return "\(modifiers.symbols)\(keyName)"
    }

    public var keycapSymbols: [String] {
        var items = modifiers.symbolList
        if let code = keyCode {
            items.append(KeyCodeHelper.string(for: code))
        }
        return items
    }

    // MARK: - Menu Bar Key Equivalent

    public var keyEquivalent: String {
        guard let code = keyCode else { return "" }
        return KeyCodeHelper.keyEquivalent(for: code)
    }

    public var keyEquivalentModifierMask: NSEvent.ModifierFlags {
        modifiers.nsModifierFlags
    }

    // MARK: - Event Matching

    public func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard let targetKey = self.keyCode else { return false }
        guard targetKey == UInt16(keyCode) else { return false }
        let currentMods = ShortcutModifiers(cgFlags: flags)
        return currentMods == self.modifiers
    }

    public func matchesModifiers(flags: CGEventFlags) -> Bool {
        guard isModifierOnly else { return false }
        let currentMods = ShortcutModifiers(cgFlags: flags)
        return currentMods == self.modifiers
    }
}

// MARK: - KeyCodeHelper

public enum KeyCodeHelper {
    public static func string(for keyCode: UInt16) -> String {
        switch CGKeyCode(keyCode) {
        case KeyConstants.kVK_ANSI_A: return "A"
        case KeyConstants.kVK_ANSI_B: return "B"
        case KeyConstants.kVK_ANSI_C: return "C"
        case KeyConstants.kVK_ANSI_D: return "D"
        case KeyConstants.kVK_ANSI_E: return "E"
        case KeyConstants.kVK_ANSI_F: return "F"
        case KeyConstants.kVK_ANSI_G: return "G"
        case KeyConstants.kVK_ANSI_H: return "H"
        case KeyConstants.kVK_ANSI_I: return "I"
        case KeyConstants.kVK_ANSI_J: return "J"
        case KeyConstants.kVK_ANSI_K: return "K"
        case KeyConstants.kVK_ANSI_L: return "L"
        case KeyConstants.kVK_ANSI_M: return "M"
        case KeyConstants.kVK_ANSI_N: return "N"
        case KeyConstants.kVK_ANSI_O: return "O"
        case KeyConstants.kVK_ANSI_P: return "P"
        case KeyConstants.kVK_ANSI_Q: return "Q"
        case KeyConstants.kVK_ANSI_R: return "R"
        case KeyConstants.kVK_ANSI_S: return "S"
        case KeyConstants.kVK_ANSI_T: return "T"
        case KeyConstants.kVK_ANSI_U: return "U"
        case KeyConstants.kVK_ANSI_V: return "V"
        case KeyConstants.kVK_ANSI_W: return "W"
        case KeyConstants.kVK_ANSI_X: return "X"
        case KeyConstants.kVK_ANSI_Y: return "Y"
        case KeyConstants.kVK_ANSI_Z: return "Z"

        case KeyConstants.kVK_ANSI_0: return "0"
        case KeyConstants.kVK_ANSI_1: return "1"
        case KeyConstants.kVK_ANSI_2: return "2"
        case KeyConstants.kVK_ANSI_3: return "3"
        case KeyConstants.kVK_ANSI_4: return "4"
        case KeyConstants.kVK_ANSI_5: return "5"
        case KeyConstants.kVK_ANSI_6: return "6"
        case KeyConstants.kVK_ANSI_7: return "7"
        case KeyConstants.kVK_ANSI_8: return "8"
        case KeyConstants.kVK_ANSI_9: return "9"

        case KeyConstants.kVK_Space: return "Space"
        case KeyConstants.kVK_Return: return "↩"
        case KeyConstants.kVK_Tab: return "⇥"
        case KeyConstants.kVK_Escape: return "⎋"
        case KeyConstants.kVK_Delete: return "⌫"
        case KeyConstants.kVK_ForwardDelete: return "⌦"

        case KeyConstants.kVK_LeftArrow: return "←"
        case KeyConstants.kVK_RightArrow: return "→"
        case KeyConstants.kVK_UpArrow: return "↑"
        case KeyConstants.kVK_DownArrow: return "↓"
        case KeyConstants.kVK_Home: return "Home"
        case KeyConstants.kVK_End: return "End"
        case KeyConstants.kVK_PageUp: return "Page Up"
        case KeyConstants.kVK_PageDown: return "Page Down"

        case KeyConstants.kVK_F1: return "F1"
        case KeyConstants.kVK_F2: return "F2"
        case KeyConstants.kVK_F3: return "F3"
        case KeyConstants.kVK_F4: return "F4"
        case KeyConstants.kVK_F5: return "F5"
        case KeyConstants.kVK_F6: return "F6"
        case KeyConstants.kVK_F7: return "F7"
        case KeyConstants.kVK_F8: return "F8"
        case KeyConstants.kVK_F9: return "F9"
        case KeyConstants.kVK_F10: return "F10"
        case KeyConstants.kVK_F11: return "F11"
        case KeyConstants.kVK_F12: return "F12"
        case KeyConstants.kVK_F13: return "F13"
        case KeyConstants.kVK_F14: return "F14"
        case KeyConstants.kVK_F15: return "F15"
        case KeyConstants.kVK_F16: return "F16"
        case KeyConstants.kVK_F17: return "F17"
        case KeyConstants.kVK_F18: return "F18"
        case KeyConstants.kVK_F19: return "F19"
        case KeyConstants.kVK_F20: return "F20"

        case KeyConstants.kVK_ANSI_Keypad0: return "Num 0"
        case KeyConstants.kVK_ANSI_Keypad1: return "Num 1"
        case KeyConstants.kVK_ANSI_Keypad2: return "Num 2"
        case KeyConstants.kVK_ANSI_Keypad3: return "Num 3"
        case KeyConstants.kVK_ANSI_Keypad4: return "Num 4"
        case KeyConstants.kVK_ANSI_Keypad5: return "Num 5"
        case KeyConstants.kVK_ANSI_Keypad6: return "Num 6"
        case KeyConstants.kVK_ANSI_Keypad7: return "Num 7"
        case KeyConstants.kVK_ANSI_Keypad8: return "Num 8"
        case KeyConstants.kVK_ANSI_Keypad9: return "Num 9"
        case KeyConstants.kVK_ANSI_KeypadDecimal: return "Num ."
        case KeyConstants.kVK_ANSI_KeypadMultiply: return "Num *"
        case KeyConstants.kVK_ANSI_KeypadPlus: return "Num +"
        case KeyConstants.kVK_ANSI_KeypadDivide: return "Num /"
        case KeyConstants.kVK_ANSI_KeypadMinus: return "Num -"
        case KeyConstants.kVK_ANSI_KeypadEquals: return "Num ="
        case KeyConstants.kVK_ANSI_KeypadEnter: return "Num ↩"
        case KeyConstants.kVK_ANSI_KeypadClear: return "Num Clear"

        case KeyConstants.kVK_ANSI_Minus: return "-"
        case KeyConstants.kVK_ANSI_Equal: return "="
        case KeyConstants.kVK_ANSI_LeftBracket: return "["
        case KeyConstants.kVK_ANSI_RightBracket: return "]"
        case KeyConstants.kVK_ANSI_Backslash: return "\\"
        case KeyConstants.kVK_ANSI_Semicolon: return ";"
        case KeyConstants.kVK_ANSI_Quote: return "'"
        case KeyConstants.kVK_ANSI_Comma: return ","
        case KeyConstants.kVK_ANSI_Period: return "."
        case KeyConstants.kVK_ANSI_Slash: return "/"
        case KeyConstants.kVK_ANSI_Grave: return "`"

        default:
            return "Key(\(keyCode))"
        }
    }

    private static let functionKeyCodes: Set<CGKeyCode> = [
        KeyConstants.kVK_F1, KeyConstants.kVK_F2, KeyConstants.kVK_F3, KeyConstants.kVK_F4,
        KeyConstants.kVK_F5, KeyConstants.kVK_F6, KeyConstants.kVK_F7, KeyConstants.kVK_F8,
        KeyConstants.kVK_F9, KeyConstants.kVK_F10, KeyConstants.kVK_F11, KeyConstants.kVK_F12,
        KeyConstants.kVK_F13, KeyConstants.kVK_F14, KeyConstants.kVK_F15, KeyConstants.kVK_F16,
        KeyConstants.kVK_F17, KeyConstants.kVK_F18, KeyConstants.kVK_F19, KeyConstants.kVK_F20
    ]

    public static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        return functionKeyCodes.contains(CGKeyCode(keyCode))
    }

    public static func keyEquivalent(for keyCode: UInt16) -> String {
        let str = string(for: keyCode)
        if str.count == 1 {
            return str.lowercased()
        }
        if keyCode == UInt16(KeyConstants.kVK_Space) {
            return " "
        }
        return ""
    }
}
