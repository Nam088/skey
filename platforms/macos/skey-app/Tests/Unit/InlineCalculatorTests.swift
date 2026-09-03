import XCTest
@testable import SKey

final class InlineCalculatorTests: XCTestCase {
    var calculator: InlineCalculator!

    override func setUp() {
        super.setUp()
        calculator = InlineCalculator()
    }

    func testSimpleMultiplication() {
        // Typing "=150*12="
        for ch in "=150*12" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let result = calculator.process(char: "=")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.resultText, "1800")
        XCTAssertEqual(result?.backspaces, 7, "Chars on screen before closing '=' is '=150*12' (7 chars)")
    }

    func testOrderOfOperationsAndDivision() {
        // Typing "=100+200/4=" -> 100 + 50 = 150
        for ch in "=100+200/4" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let result = calculator.process(char: "=")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.resultText, "150")
        XCTAssertEqual(result?.backspaces, 10, "Chars on screen before closing '=' is '=100+200/4' (10 chars)")
    }

    func testAlternativeMultiplicationAndDivisionOperators() {
        // Using 'x' for multiplication: "=25x4="
        calculator.reset()
        for ch in "=25x4" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let multResult = calculator.process(char: "=")
        XCTAssertNotNil(multResult)
        XCTAssertEqual(multResult?.resultText, "100")

        // Using ':' for division: "=100:5="
        calculator.reset()
        for ch in "=100:5" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let divResult = calculator.process(char: "=")
        XCTAssertNotNil(divResult)
        XCTAssertEqual(divResult?.resultText, "20")
    }

    func testPercentageEvaluation() {
        // "=500*10%=" -> 50
        calculator.reset()
        for ch in "=500*10%" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let result = calculator.process(char: "=")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.resultText, "50")
    }

    func testInvalidMathExpressionDoesNotEvaluate() {
        // "=abc=" -> should not evaluate
        calculator.reset()
        for ch in "=abc" {
            XCTAssertNil(calculator.process(char: ch))
        }
        let result = calculator.process(char: "=")
        XCTAssertNil(result)
    }

    func testBackspaceCleansBuffer() {
        calculator.reset()
        for ch in "=150*" {
            _ = calculator.process(char: ch)
        }
        calculator.recordBackspace() // deletes '*'
        _ = calculator.process(char: "+")
        _ = calculator.process(char: "5")
        let result = calculator.process(char: "=")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.resultText, "155")
    }

    func testScientificFunctionsAndFactorial() {
        calculator.reset()
        for ch in "=sqrt(144)=" {
            _ = calculator.process(char: ch)
        }
        XCTAssertEqual(calculator.evaluate("sqrt(144)"), "12")
        XCTAssertEqual(calculator.evaluate("cbrt(27)"), "3")
        XCTAssertEqual(calculator.evaluate("5!"), "120")
        XCTAssertEqual(calculator.evaluate("2^10"), "1024")
        XCTAssertEqual(calculator.evaluate("min(15, 30)"), "15")
        XCTAssertEqual(calculator.evaluate("max(15, 30)"), "30")
        XCTAssertEqual(calculator.evaluate("sind(90)"), "1")
        XCTAssertEqual(calculator.evaluate("cosd(0)"), "1")
    }

    func testProgrammerBitwiseAndHex() {
        XCTAssertEqual(calculator.evaluate("0xFF + 1"), "256")
        XCTAssertEqual(calculator.evaluate("0b1010 + 0b0101"), "15")
        XCTAssertEqual(calculator.evaluate("1 << 4"), "16")
        XCTAssertEqual(calculator.evaluate("12 & 10"), "8")
        XCTAssertEqual(calculator.evaluate("12 | 10"), "14")
    }

    func testSpaceResetsBufferForSafety() {
        // Typing "=150*12 " followed by "=" -> space must cancel/reset calculation
        calculator.reset()
        for ch in "=150*12 " {
            XCTAssertNil(calculator.process(char: ch))
        }
        let result = calculator.process(char: "=")
        XCTAssertNil(result, "Space must have reset buffer, so '=' starts a new buffer instead of calculating")
    }

    func testTypoCorrectionWithBackspace() {
        // Typing "=100*" -> backspace -> "+50=" -> evaluates to 150
        calculator.reset()
        for ch in "=100*" {
            _ = calculator.process(char: ch)
        }
        calculator.recordBackspace() // deletes '*'
        for ch in "+50" {
            _ = calculator.process(char: ch)
        }
        let result = calculator.process(char: "=")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.resultText, "150")
    }
}
