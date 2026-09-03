import XCTest
@testable import SKey

final class MacroEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppSettings.shared.macro.isEnabled = true
        AppSettings.shared.macro.autoCaps = true
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "vn", replacement: "Việt Nam"),
            MacroItem(shortcut: "hn", replacement: "Hà Nội ")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()
    }

    func testEvaluateMacroOnSpaceAppendsTrailingSpace() {
        MacroEngine.shared.recordChar("v")
        MacroEngine.shared.recordChar("n")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2)
        XCTAssertEqual(result.replacement, "Việt Nam ", "Macro triggered on space must include the trailing space so following words are not joined")
    }

    func testEvaluateMacroOnSpaceWithAutoCaps() {
        MacroEngine.shared.recordChar("V")
        MacroEngine.shared.recordChar("N")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2)
        XCTAssertEqual(result.replacement, "VIỆT NAM ")
    }

    func testEvaluateMacroDoesNotDoubleTrailingSpace() {
        MacroEngine.shared.recordChar("h")
        MacroEngine.shared.recordChar("n")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2)
        XCTAssertEqual(result.replacement, "Hà Nội ", "Should not append second space if replacement already ends with space")
    }

    func testVietnameseMacroExpansionWithTransformedCharacters() {
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "đc", replacement: "được"),
            MacroItem(shortcut: "ủa", replacement: "ủa alo"),
            MacroItem(shortcut: "hđ", replacement: "hợp đồng")
        ]
        MacroEngine.shared.reloadMacros()

        // User types 'd', then 'd' (which engine transforms to bs=1, text="đ"), then 'c'
        MacroEngine.shared.recordChar("d")
        MacroEngine.shared.recordTransform(backspaces: 1, text: "đ")
        MacroEngine.shared.recordChar("c")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2, "Backspaces should be exactly 2 for 'đc', not 3")
        XCTAssertEqual(result.replacement, "được ")
    }

    func testVietnameseMacroWithDiacriticVowels() {
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "ủa", replacement: "ủa alo")
        ]
        MacroEngine.shared.reloadMacros()

        // User types 'u', then 'a', then 'r' (engine transforms to bs=2, text="ủa")
        MacroEngine.shared.recordChar("u")
        MacroEngine.shared.recordChar("a")
        MacroEngine.shared.recordTransform(backspaces: 2, text: "ủa")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2, "Backspaces should be exactly 2 for 'ủa'")
        XCTAssertEqual(result.replacement, "ủa alo ")
    }

    func testVietnameseMacroWithAutoCaps() {
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "đc", replacement: "được")
        ]
        MacroEngine.shared.reloadMacros()

        // User types uppercase "ĐC"
        MacroEngine.shared.recordChar("D")
        MacroEngine.shared.recordTransform(backspaces: 1, text: "Đ")
        MacroEngine.shared.recordChar("C")

        let allCapsResult = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(allCapsResult.handled)
        XCTAssertEqual(allCapsResult.backspaces, 2)
        XCTAssertEqual(allCapsResult.replacement, "ĐƯỢC ")

        // User types title case "Đc"
        MacroEngine.shared.recordChar("D")
        MacroEngine.shared.recordTransform(backspaces: 1, text: "Đ")
        MacroEngine.shared.recordChar("c")

        let titleCapsResult = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(titleCapsResult.handled)
        XCTAssertEqual(titleCapsResult.backspaces, 2)
        XCTAssertEqual(titleCapsResult.replacement, "Được ")
    }

    func testVietnameseMacroWithConsonantTransforms() {
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "hđ", replacement: "hợp đồng")
        ]
        MacroEngine.shared.reloadMacros()

        // User types 'h', then 'd', then 'd' (transforms to bs=1, text="đ")
        MacroEngine.shared.recordChar("h")
        MacroEngine.shared.recordChar("d")
        MacroEngine.shared.recordTransform(backspaces: 1, text: "đ")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 2, "Backspaces should be exactly 2 for 'hđ'")
        XCTAssertEqual(result.replacement, "hợp đồng ")
    }

    func testDynamicVariablesInMacro() {
        AppSettings.shared.macro.dynamicVariablesEnabled = true
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "ngay", replacement: "Hôm nay là {date}")
        ]
        MacroEngine.shared.reloadMacros()

        MacroEngine.shared.recordChar("n")
        MacroEngine.shared.recordChar("g")
        MacroEngine.shared.recordChar("a")
        MacroEngine.shared.recordChar("y")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertFalse(result.replacement.contains("{date}"), "Replacement must resolve {date}")
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let expectedDate = formatter.string(from: Date())
        XCTAssertTrue(result.replacement.contains(expectedDate))
    }

    func testDynamicVariablesDisabledLeavesRawText() {
        AppSettings.shared.macro.dynamicVariablesEnabled = false
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "ngay", replacement: "Hôm nay là {date}")
        ]
        MacroEngine.shared.reloadMacros()

        MacroEngine.shared.recordChar("n")
        MacroEngine.shared.recordChar("g")
        MacroEngine.shared.recordChar("a")
        MacroEngine.shared.recordChar("y")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertTrue(result.replacement.contains("{date}"), "When disabled, {date} must remain as raw text")
    }

    func testDynamicVariablesWithAutoCaps() {
        AppSettings.shared.macro.dynamicVariablesEnabled = true
        AppSettings.shared.macro.autoCaps = true
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "ngay", replacement: "{datetime} {clipboard}")
        ]
        MacroEngine.shared.reloadMacros()

        // Typing all caps "NGAY" will trigger autoCaps uppercasing replacement to "{DATETIME} {CLIPBOARD}"
        MacroEngine.shared.recordChar("N")
        MacroEngine.shared.recordChar("G")
        MacroEngine.shared.recordChar("A")
        MacroEngine.shared.recordChar("Y")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertFalse(result.replacement.contains("{DATETIME}"), "Must resolve {DATETIME} even when autoCaps uppercased it")
        XCTAssertFalse(result.replacement.contains("{CLIPBOARD}"), "Must resolve {CLIPBOARD} even when autoCaps uppercased it")
    }

    func testHehuMacroWithClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("{date}a", forType: .string)

        AppSettings.shared.macro.dynamicVariablesEnabled = true
        AppSettings.shared.macro.autoCaps = false
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "hehu", replacement: "{datetime} {clipboard}")
        ]
        MacroEngine.shared.reloadMacros()

        MacroEngine.shared.recordChar("h")
        MacroEngine.shared.recordChar("e")
        MacroEngine.shared.recordChar("h")
        MacroEngine.shared.recordChar("u")

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        print(">>> RESULT REPLACEMENT: [\(result.replacement)]")
        XCTAssertTrue(result.handled)
    }

    func testCustomConstantsExpansion() {
        AppSettings.shared.macro.dynamicVariablesEnabled = true
        AppSettings.shared.macro.autoCaps = false
        AppSettings.shared.macro.constants = [
            MacroConstant(key: "email", value: "nam088@gmail.com"),
            MacroConstant(key: "sdt", value: "0901234567")
        ]
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "lienhe", replacement: "Mail: {$email} - Tel: {$sdt}")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()

        for ch in "lienhe" {
            MacroEngine.shared.recordChar(ch)
        }

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertTrue(result.replacement.contains("nam088@gmail.com"))
        XCTAssertTrue(result.replacement.contains("0901234567"))
        XCTAssertFalse(result.replacement.contains("{$email}"))
        XCTAssertFalse(result.replacement.contains("{$sdt}"))
    }

    func testRichDynamicVariables() {
        AppSettings.shared.macro.dynamicVariablesEnabled = true
        AppSettings.shared.macro.autoCaps = false
        AppSettings.shared.macro.items = [
            MacroItem(shortcut: "meta", replacement: "Year: {year}, TS: {timestamp}, UUID: {uuid}")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()

        for ch in "meta" {
            MacroEngine.shared.recordChar(ch)
        }

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertFalse(result.replacement.contains("{year}"))
        XCTAssertFalse(result.replacement.contains("{timestamp}"))
        XCTAssertFalse(result.replacement.contains("{uuid}"))
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(result.replacement.contains(String(currentYear)))
    }

    func testDirectConstantExpansionWithDefaultPrefix() {
        AppSettings.shared.macro.isEnabled = true
        AppSettings.shared.macro.directConstantsEnabled = true
        AppSettings.shared.macro.constantPrefix = ":"
        AppSettings.shared.macro.constants = [
            MacroConstant(key: "email", value: "nam088@gmail.com")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()

        for ch in ":email" {
            MacroEngine.shared.recordChar(ch)
        }

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 6)
        XCTAssertEqual(result.replacement, "nam088@gmail.com ")
    }

    func testDirectConstantExpansionWithCustomPrefix() {
        AppSettings.shared.macro.isEnabled = true
        AppSettings.shared.macro.directConstantsEnabled = true
        AppSettings.shared.macro.constantPrefix = "$"
        AppSettings.shared.macro.constants = [
            MacroConstant(key: "sdt", value: "0901234567")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()

        for ch in "$sdt" {
            MacroEngine.shared.recordChar(ch)
        }

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.backspaces, 4)
        XCTAssertEqual(result.replacement, "0901234567 ")

        // Test preview / testExpand
        let testResult = MacroEngine.shared.testExpand(shortcut: "$sdt")
        XCTAssertEqual(testResult, "0901234567")
    }

    func testDirectConstantExpansionDisabled() {
        AppSettings.shared.macro.isEnabled = true
        AppSettings.shared.macro.directConstantsEnabled = false
        AppSettings.shared.macro.constantPrefix = ":"
        AppSettings.shared.macro.constants = [
            MacroConstant(key: "email", value: "nam088@gmail.com")
        ]
        MacroEngine.shared.reloadMacros()
        MacroEngine.shared.reset()

        for ch in ":email" {
            MacroEngine.shared.recordChar(ch)
        }

        let result = MacroEngine.shared.evaluateMacroOnSpace()
        XCTAssertFalse(result.handled)
    }
}
