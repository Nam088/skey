import Foundation

@main
struct TestDill {
    static func main() {
        let engine = SKeyEngine()
        engine.setInputMethod(.telex)

        let word = "Diễu"
        let keys = VietnameseDecomposer.decompose(word: word)
        let keyStrs = keys.map { String(UnicodeScalar($0) ?? " ") }.joined()
        print("Word: '\(word)' -> Decomposed: '\(keyStrs)'")

        var reconstructed = ""
        for k in keys {
            let r = engine.filter(character: k)
            if r.handled {
                let bs = r.backspaces
                if bs > 0 && bs <= reconstructed.count {
                    reconstructed.removeLast(bs)
                }
                reconstructed.append(r.text)
            } else if let s = UnicodeScalar(k) {
                reconstructed.append(Character(s))
            }
        }
        print("Reconstructed before 'r': '\(reconstructed)'")

        // Press 'r'
        guard let rScalar = Character("r").unicodeScalars.first else { return }
        let res = engine.filter(character: rScalar.value)
        print("Handled: \(res.handled), backspaces: \(res.backspaces), text: '\(res.text)'")

        if res.handled {
            let bs = res.backspaces
            if bs > 0 && bs <= reconstructed.count {
                reconstructed.removeLast(bs)
            }
            reconstructed.append(res.text)
        }
        print("Result after 'r': '\(reconstructed)' (Expected: 'Diểu')")
    }
}
