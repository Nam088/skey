import Foundation

@main
struct FullWordRecomposeTest {
    static func main() {
        print("--- Testing Full Word Reconstruction ---")
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
            ("chuyên", "x", "chuyễn"),
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

            // Strategy: Reconstruct full word
            // We want the word produced by typing keys WITHOUT old tone mark + with NEW tone mark!
            // Or typing keys and then the new key!
            engine.reset()
            var reconstructedWord = ""
            for k in keys {
                let r = engine.filter(character: k)
                if r.handled {
                    // incremental update
                    let bs = r.backspaces
                    if bs > 0 && bs <= reconstructedWord.count {
                        reconstructedWord.removeLast(bs)
                    }
                    reconstructedWord.append(r.text)
                } else if let scalar = UnicodeScalar(k) {
                    reconstructedWord.append(Character(scalar))
                }
            }

            // Now apply the new keyChar
            guard let scalar = tc.keyChar.unicodeScalars.first else { continue }
            let finalRes = engine.filter(character: scalar.value)
            if finalRes.handled {
                let bs = finalRes.backspaces
                if bs > 0 && bs <= reconstructedWord.count {
                    reconstructedWord.removeLast(bs)
                }
                reconstructedWord.append(finalRes.text)
            } else {
                reconstructedWord.append(tc.keyChar)
            }

            print("Testing '\(tc.word)' + '\(tc.keyChar)': Reconstructed -> '\(reconstructedWord)' (Expected: '\(tc.expectedWord)')")
            if reconstructedWord == tc.expectedWord {
                print("  => [PASS]")
                passedCount += 1
            } else {
                print("  => [FAIL]")
            }
        }

        print("\n=======================================================")
        print("Score: \(passedCount)/\(wordsToTest.count) tests passed")
        print("=======================================================")
    }
}
