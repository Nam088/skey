import Foundation

@main
struct DecomposerRecomposerTest {
    static func main() {
        print("--- Testing VietnameseDecomposer + SKeyEngine Recomposition ---")
        let engine = SKeyEngine()
        engine.setInputMethod(.telex)

        let wordsToTest: [(word: String, keyChar: Character, expectedWord: String)] = [
            ("ấn", "f", "ần"),
            ("ấn", "r", "ẩn"),
            ("ấn", "x", "ẫn"),
            ("ấn", "j", "ận"),
            ("ấn", "z", "ân"),
            ("tượng", "s", "tướng"),
            ("tượng", "f", "tường"),
            ("tượng", "r", "tưởng"),
            ("tượng", "x", "tưỡng"),
            ("tượng", "z", "tương"),
            ("chuyên", "s", "chuyến"),
            ("chuyên", "f", "chuyền"),
            ("chuyên", "r", "chuyển"),
            ("chuyên", "j", "chuyện"),
            ("sâu", "s", "sấu"),
            ("sâu", "f", "sầu"),
            ("sâu", "r", "sẩu"),
            ("sâu", "j", "sậu"),
            ("sâu", "x", "sẫu")
        ]

        var passedCount = 0
        for tc in wordsToTest {
            let keys = VietnameseDecomposer.decompose(word: tc.word)
            let keyStrings = keys.map { String(UnicodeScalar($0) ?? " ") }.joined()
            print("\nTesting: '\(tc.word)' (decomposed: '\(keyStrings)') + '\(tc.keyChar)':")

            engine.reset()
            for k in keys {
                _ = engine.filter(character: k)
            }
            guard let scalar = tc.keyChar.unicodeScalars.first else { continue }
            let res = engine.filter(character: scalar.value)

            print("  Result: handled=\(res.handled), backspaces=\(res.backspaces), text='\(res.text)'")
            if res.handled && res.text == tc.expectedWord {
                print("  => [PASS] Got '\(res.text)' (expected '\(tc.expectedWord)')")
                passedCount += 1
            } else {
                print("  => [FAIL] Got '\(res.text)' (expected '\(tc.expectedWord)')")
            }
        }

        print("\n=======================================================")
        print("Score: \(passedCount)/\(wordsToTest.count) tests passed")
        print("=======================================================")
    }
}
