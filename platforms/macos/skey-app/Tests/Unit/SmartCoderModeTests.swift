import XCTest
@testable import SKey

final class SmartCoderModeTests: XCTestCase {
    var detector: SmartCoderModeDetector!

    override func setUp() {
        super.setUp()
        detector = SmartCoderModeDetector()
    }

    func testCamelCaseDetection() {
        // Typing "myVariable"
        XCTAssertFalse(detector.process(char: "m"))
        XCTAssertFalse(detector.process(char: "y"))
        // Uppercase 'V' after lowercase letters triggers CamelCase code mode
        XCTAssertTrue(detector.process(char: "V"), "Uppercase after lowercase must be detected as CamelCase")
        XCTAssertTrue(detector.process(char: "a"), "Subsequent characters in CamelCase must stay in code mode")
        XCTAssertTrue(detector.process(char: "r"))
        XCTAssertTrue(detector.process(char: "i"))

        // Space resets code mode
        XCTAssertFalse(detector.process(char: " "))
        XCTAssertFalse(detector.process(char: "v"))
    }

    func testCodePrefixTokens() {
        // Leading '_' like "_id"
        detector.reset()
        XCTAssertTrue(detector.process(char: "_"), "Leading '_' must trigger code token")
        XCTAssertTrue(detector.process(char: "i"))
        XCTAssertTrue(detector.process(char: "d"))

        // Leading '$' like "$state"
        detector.reset()
        XCTAssertTrue(detector.process(char: "$"), "Leading '$' must trigger code token")
        XCTAssertTrue(detector.process(char: "s"))

        // Leading '@' like "@State"
        detector.reset()
        XCTAssertTrue(detector.process(char: "@"), "Leading '@' must trigger code token")
        XCTAssertTrue(detector.process(char: "S"))

        // Leading '-' like "--dev"
        detector.reset()
        XCTAssertTrue(detector.process(char: "-"), "Leading '-' must trigger code token")
        XCTAssertTrue(detector.process(char: "-"))
        XCTAssertTrue(detector.process(char: "d"))

        // Leading '/' like "/api"
        detector.reset()
        XCTAssertTrue(detector.process(char: "/"), "Leading '/' must trigger code token")
        XCTAssertTrue(detector.process(char: "a"))
    }

    func testSnakeCaseAndKebabCase() {
        // "user_name"
        detector.reset()
        XCTAssertFalse(detector.process(char: "u"))
        XCTAssertFalse(detector.process(char: "s"))
        XCTAssertFalse(detector.process(char: "e"))
        XCTAssertFalse(detector.process(char: "r"))
        XCTAssertTrue(detector.process(char: "_"), "Underscore inside word triggers code token")
        XCTAssertTrue(detector.process(char: "n"))
        XCTAssertTrue(detector.process(char: "a"))

        // "font-size"
        detector.reset()
        XCTAssertFalse(detector.process(char: "f"))
        XCTAssertFalse(detector.process(char: "o"))
        XCTAssertTrue(detector.process(char: "-"), "Hyphen inside word triggers code token")
        XCTAssertTrue(detector.process(char: "s"))
    }

    func testNormalCapitalizedVietnameseIsNotCodeToken() {
        // "Việt" (starts with uppercase 'V', followed by lowercase)
        detector.reset()
        XCTAssertFalse(detector.process(char: "V"), "TitleCase initial uppercase must NOT trigger code token")
        XCTAssertFalse(detector.process(char: "i"))
        XCTAssertFalse(detector.process(char: "e"))
        XCTAssertFalse(detector.process(char: "t"))

        // "Hà"
        detector.reset()
        XCTAssertFalse(detector.process(char: "H"))
        XCTAssertFalse(detector.process(char: "a"))
    }

    func testAllCapsVietnameseIsNotCodeToken() {
        // "VIET" (all uppercase)
        detector.reset()
        XCTAssertFalse(detector.process(char: "V"))
        XCTAssertFalse(detector.process(char: "I"))
        XCTAssertFalse(detector.process(char: "E"))
        XCTAssertFalse(detector.process(char: "T"))
    }

    func testBackspaceRevertsState() {
        detector.reset()
        _ = detector.process(char: "m")
        _ = detector.process(char: "y")
        _ = detector.process(char: "V") // Triggers code mode

        // Backspace 'V'
        detector.recordBackspace()
        // Now next char 'o' should not be forced into code mode if V was erased
        XCTAssertFalse(detector.process(char: "o"))
    }
}
