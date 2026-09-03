import XCTest
@testable import SKey

final class VietnameseDecomposerTests: XCTestCase {
    func testDecomposeLowercaseWord() {
        // "tiếng" -> t, i, e, e, n, g, s
        let keys = VietnameseDecomposer.decompose(word: "tiếng")
        let stringKeys = String(keys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(stringKeys, "tieengs")
    }

    func testDecomposeUppercaseAccentedVowels() {
        // "Áo" -> A, o, s
        let aoKeys = VietnameseDecomposer.decompose(word: "Áo")
        let aoStr = String(aoKeys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(aoStr, "Aos", "Word starting with Á should decompose to A, o, s")

        // "Ăn" -> A, w, n
        let anKeys = VietnameseDecomposer.decompose(word: "Ăn")
        let anStr = String(anKeys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(anStr, "Awn", "Word starting with Ă should decompose to A, w, n")

        // "Ổn" -> O, o, n, r
        let onKeys = VietnameseDecomposer.decompose(word: "Ổn")
        let onStr = String(onKeys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(onStr, "Oonr", "Word starting with Ổ should decompose to O, o, n, r")

        // "Ý" -> Y, s
        let yKeys = VietnameseDecomposer.decompose(word: "Ý")
        let yStr = String(yKeys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(yStr, "Ys", "Word Ý should decompose to Y, s")
    }

    func testDecomposeNFDString() {
        // NFD representation of "ế" = 'e' (101) + circumflex (0x0302) + acute (0x0301)
        let nfdString = "te\u{0302}\u{0301}ng"
        let keys = VietnameseDecomposer.decompose(word: nfdString)
        let stringKeys = String(keys.compactMap { UnicodeScalar($0).map(Character.init) })
        XCTAssertEqual(stringKeys, "teengs", "NFD string must be normalized to NFC and decomposed properly")
    }
}
