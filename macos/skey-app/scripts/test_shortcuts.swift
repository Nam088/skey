import AppKit
import Carbon
import CoreGraphics
import Foundation

@main
struct ShortcutTestRunner {
    static func main() throws {
        print("=== Running SKey Shortcut System Test Suite ===")

        // 1. Test ShortcutModifiers OptionSet
        print("\n--- Test 1: ShortcutModifiers ---")
        let mods: ShortcutModifiers = [.option, .shift]
        assert(mods.contains(.option))
        assert(mods.contains(.shift))
        assert(!mods.contains(.command))
        assert(!mods.contains(.control))
        assert(mods.symbols == "⌥⇧")
        assert(mods.symbolList == ["⌥", "⇧"])
        print("✓ ShortcutModifiers flags and symbol formatting passed")

        // 2. Test KeyShortcut Presets
        print("\n--- Test 2: KeyShortcut Presets ---")
        let optZ = KeyShortcut.optionZ
        assert(!optZ.isModifierOnly)
        assert(optZ.keyCode == UInt16(KeyConstants.kVK_ANSI_Z))
        assert(optZ.modifiers == .option)
        assert(optZ.displayString == "⌥Z")
        assert(optZ.keyEquivalent == "z")
        assert(optZ.keyEquivalentModifierMask == .option)
        print("✓ KeyShortcut.optionZ passed: \(optZ.displayString)")

        let ctrlShift = KeyShortcut.ctrlShift
        assert(ctrlShift.isModifierOnly)
        assert(ctrlShift.keyCode == nil)
        assert(ctrlShift.modifiers == [.control, .shift])
        assert(ctrlShift.displayString == "⌃⇧")
        assert(ctrlShift.keyEquivalent == "")
        print("✓ KeyShortcut.ctrlShift (modifier-only) passed: \(ctrlShift.displayString)")

        let cmdShiftV = KeyShortcut.cmdShiftV
        assert(!cmdShiftV.isModifierOnly)
        assert(cmdShiftV.displayString == "⇧⌘V")
        print("✓ KeyShortcut.cmdShiftV passed: \(cmdShiftV.displayString)")

        let optShift = KeyShortcut.optionShift
        assert(optShift.isModifierOnly)
        assert(optShift.modifiers == [.option, .shift])
        assert(optShift.displayString == "⌥⇧")
        print("✓ KeyShortcut.optionShift passed: \(optShift.displayString)")

        // 3. Test KeyCodeHelper
        print("\n--- Test 3: KeyCodeHelper All Key Mappings ---")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_ANSI_A)) == "A")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_ANSI_Z)) == "Z")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_ANSI_0)) == "0")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_Space)) == "Space")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_Return)) == "↩")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_Tab)) == "⇥")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_Escape)) == "⎋")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_F1)) == "F1")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_F12)) == "F12")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_ANSI_Keypad1)) == "Num 1")
        assert(KeyCodeHelper.string(for: UInt16(KeyConstants.kVK_ANSI_KeypadPlus)) == "Num +")
        print("✓ KeyCodeHelper properly maps standard, function, and numpad keys")

        // 4. Test Codable Serialization (for settings storage & JSON backups)
        print("\n--- Test 4: Codable Persistence ---")
        let customShortcut = KeyShortcut(keyCode: UInt16(KeyConstants.kVK_ANSI_K), modifiers: [.command, .option])
        let encoder = JSONEncoder()
        let data = try encoder.encode(customShortcut)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KeyShortcut.self, from: data)
        assert(decoded == customShortcut)
        assert(decoded.displayString == "⌥⌘K")
        print("✓ JSON encoding and decoding succeeded: \(decoded.displayString)")

        // 5. Test Event Matching
        print("\n--- Test 5: Event Matching ---")
        let zKeyCode = CGKeyCode(KeyConstants.kVK_ANSI_Z)
        let optFlags: CGEventFlags = [.maskAlternate]
        let ctrlOptFlags: CGEventFlags = [.maskAlternate, .maskControl]

        assert(optZ.matches(keyCode: zKeyCode, flags: optFlags))
        assert(!optZ.matches(keyCode: zKeyCode, flags: ctrlOptFlags)) // Extra modifier shouldn't match
        assert(!optZ.matches(keyCode: CGKeyCode(KeyConstants.kVK_ANSI_A), flags: optFlags)) // Different key

        let ctrlOptZ = KeyShortcut.ctrlOptionZ
        assert(ctrlOptZ.matches(keyCode: zKeyCode, flags: ctrlOptFlags))
        assert(!ctrlOptZ.matches(keyCode: zKeyCode, flags: optFlags))
        print("✓ CGEvent keyCode & flags matching logic verified")

        // 6. Test Conflict Detection Logic
        print("\n--- Test 6: Conflict Detection ---")
        let settings = AppSettings.shared.shortcuts
        settings.resetToDefaults()

        // Default: language = optZ, clipboard = optV, cleaner = optShiftK, ai = optSpace
        assert(settings.findConflict(for: .optionZ, excluding: .languageToggle) == nil)
        assert(settings.findConflict(for: .optionV, excluding: .clipboard) == nil)

        // Test simulating a conflict: setting language toggle shortcut to optionV
        let conflictTarget = settings.findConflict(for: .optionV, excluding: .languageToggle)
        assert(conflictTarget == .clipboard)
        print("✓ Successfully detected conflict when setting shortcut to optionV (conflicted with: \(conflictTarget?.displayName ?? ""))")

        print("\n=== ALL SHORTCUT TESTS PASSED SUCCESSFULLY! ===")
    }
}
