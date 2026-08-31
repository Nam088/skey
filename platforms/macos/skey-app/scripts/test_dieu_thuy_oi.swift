import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@main
struct TestDieuThuyOi {
    static func main() {
        let sentence = "Diễu Thuý ơi"
        print("Sentence: '\(sentence)' (Length: \(sentence.utf16.count))")

        for loc in 1...sentence.utf16.count {
            let prefixIndex = sentence.utf16.index(sentence.utf16.startIndex, offsetBy: loc)
            let prefix = String(sentence.utf16[..<prefixIndex]) ?? ""
            
            // Extract last word logic
            var word = ""
            if let lastChar = prefix.last, !lastChar.isWhitespace && !lastChar.isPunctuation {
                var scalars: [Unicode.Scalar] = []
                for s in prefix.unicodeScalars.reversed() {
                    let c = Character(s)
                    if c.isWhitespace || c.isPunctuation { break }
                    scalars.append(s)
                }
                word = String(String.UnicodeScalarView(scalars.reversed()))
            }

            print("Location \(loc) (Prefix: '\(prefix)'): Preceding Word -> '\(word)'")
        }
    }
}
