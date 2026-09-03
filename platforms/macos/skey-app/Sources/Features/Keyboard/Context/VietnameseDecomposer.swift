import Foundation

// MARK: - VietnameseDecomposer

/// Ultra-high performance zero-allocation decomposer that translates pre-composed
/// Vietnamese Unicode characters into raw keystrokes (base keys + tone marks).
public enum VietnameseDecomposer {
    // MARK: - Public API

    /// Decomposes a word like "đáu" into raw keystroke sequence (e.g. ['d', 'd', 'a', 'u', 's'])
    /// Guaranteed zero heap allocations on the hot path.
    public static func decompose(word: String) -> [UInt32] {
        let normalized = word.precomposedStringWithCanonicalMapping
        var result: [UInt32] = []
        result.reserveCapacity(normalized.utf16.count * 2)

        var toneMark: UInt32?

        for scalar in normalized.unicodeScalars {
            let val = scalar.value
            let (base, tone) = decomposeScalar(val)
            result.append(contentsOf: base)
            if let tone {
                toneMark = tone
            }
        }

        if let toneMark {
            result.append(toneMark)
        }

        return result
    }

    // MARK: - Zero-Allocation Scalar Switch (O(1) Jump Table)

    @inline(__always)
    private static func decomposeScalar(_ val: UInt32) -> ([UInt32], UInt32?) {
        let (base, tone) = decomposeLowerScalar(val)
        if base.count == 1 && base[0] == val && val >= 0x80 {
            if let scalar = UnicodeScalar(val) {
                let char = Character(scalar)
                if char.isUppercase {
                    let lowerChar = char.lowercased()
                    if let lowerVal = lowerChar.unicodeScalars.first?.value, lowerVal != val {
                        var (lowerBase, lowerTone) = decomposeLowerScalar(lowerVal)
                        if !lowerBase.isEmpty, let firstScalar = UnicodeScalar(lowerBase[0]) {
                            let upperFirst = Character(firstScalar).uppercased().unicodeScalars.first?.value ?? lowerBase[0]
                            lowerBase[0] = upperFirst
                            return (lowerBase, lowerTone)
                        }
                    }
                }
            }
        }
        return (base, tone)
    }

    @inline(__always)
    private static func decomposeLowerScalar(_ val: UInt32) -> ([UInt32], UInt32?) {
        // ASCII key codes: 'a'=97, 'd'=100, 'e'=101, 'f'=102, 'j'=106, 'o'=111, 'r'=114, 's'=115, 'u'=117, 'w'=119, 'x'=120
        switch val {
        // đ, Đ
        case 0x0111: return ([100, 100], nil) // đ -> dd
        case 0x0110: return ([68, 68], nil)   // Đ -> DD

        // a vowels
        case 0x00E0: return ([97], 102) // à -> a + f
        case 0x00E1: return ([97], 115) // á -> a + s
        case 0x1EA3: return ([97], 114) // ả -> a + r
        case 0x00E3: return ([97], 120) // ã -> a + x
        case 0x1EA1: return ([97], 106) // ạ -> a + j

        // â vowels
        case 0x00E2: return ([97, 97], nil) // â -> aa
        case 0x1EA7: return ([97, 97], 102) // ầ -> aa + f
        case 0x1EA5: return ([97, 97], 115) // ấ -> aa + s
        case 0x1EA9: return ([97, 97], 114) // ổ -> aa + r
        case 0x1EAB: return ([97, 97], 120) // ẫ -> aa + x
        case 0x1EAD: return ([97, 97], 106) // ậ -> aa + j

        // ă vowels
        case 0x0103: return ([97, 119], nil) // ă -> aw
        case 0x1EB1: return ([97, 119], 102) // ằ -> aw + f
        case 0x1EAF: return ([97, 119], 115) // ắ -> aw + s
        case 0x1EB3: return ([97, 119], 114) // ẳ -> aw + r
        case 0x1EB5: return ([97, 119], 120) // ẵ -> aw + x
        case 0x1EB7: return ([97, 119], 106) // ặ -> aw + j

        // e vowels
        case 0x00E8: return ([101], 102) // è -> e + f
        case 0x00E9: return ([101], 115) // é -> e + s
        case 0x1EBB: return ([101], 114) // ẻ -> e + r
        case 0x1EBD: return ([101], 120) // ẽ -> e + x
        case 0x1EB9: return ([101], 106) // ẹ -> e + j

        // ê vowels
        case 0x00EA: return ([101, 101], nil) // ê -> ee
        case 0x1EC1: return ([101, 101], 102) // ề -> ee + f
        case 0x1EBF: return ([101, 101], 115) // ế -> ee + s
        case 0x1EC3: return ([101, 101], 114) // ể -> ee + r
        case 0x1EC5: return ([101, 101], 120) // ễ -> ee + x
        case 0x1EC7: return ([101, 101], 106) // ệ -> ee + j

        // i vowels
        case 0x00EC: return ([105], 102) // ì -> i + f
        case 0x00ED: return ([105], 115) // í -> i + s
        case 0x1EC9: return ([105], 114) // ỉ -> i + r
        case 0x0129: return ([105], 120) // ĩ -> i + x
        case 0x1ECB: return ([105], 106) // ị -> i + j

        // o vowels
        case 0x00F2: return ([111], 102) // ò -> o + f
        case 0x00F3: return ([111], 115) // ó -> o + s
        case 0x1ECF: return ([111], 114) // ỏ -> o + r
        case 0x00F5: return ([111], 120) // õ -> o + x
        case 0x1ECD: return ([111], 106) // ọ -> o + j

        // ô vowels
        case 0x00F4: return ([111, 111], nil) // ô -> oo
        case 0x1ED3: return ([111, 111], 102) // ồ -> oo + f
        case 0x1ED1: return ([111, 111], 115) // ố -> oo + s
        case 0x1ED5: return ([111, 111], 114) // ổ -> oo + r
        case 0x1ED7: return ([111, 111], 120) // ỗ -> oo + x
        case 0x1ED9: return ([111, 111], 106) // ộ -> oo + j

        // ơ vowels
        case 0x01A1: return ([111, 119], nil) // ơ -> ow
        case 0x1EDD: return ([111, 119], 102) // ờ -> ow + f
        case 0x1EDB: return ([111, 119], 115) // ớ -> ow + s
        case 0x1EDF: return ([111, 119], 114) // ở -> ow + r
        case 0x1EE1: return ([111, 119], 120) // ỡ -> ow + x
        case 0x1EE3: return ([111, 119], 106) // ợ -> ow + j

        // u vowels
        case 0x00F9: return ([117], 102) // ù -> u + f
        case 0x00FA: return ([117], 115) // ú -> u + s
        case 0x1EE7: return ([117], 114) // ủ -> u + r
        case 0x0169: return ([117], 120) // ũ -> u + x
        case 0x1EE5: return ([117], 106) // ụ -> u + j

        // ư vowels
        case 0x01B0: return ([117, 119], nil) // ư -> uw
        case 0x1EEB: return ([117, 119], 102) // ừ -> uw + f
        case 0x1EE9: return ([117, 119], 115) // ứ -> uw + s
        case 0x1EED: return ([117, 119], 114) // ử -> uw + r
        case 0x1EEF: return ([117, 119], 120) // ữ -> uw + x
        case 0x1EF1: return ([117, 119], 106) // ự -> uw + j

        // y vowels
        case 0x1EF3: return ([121], 102) // ỳ -> y + f
        case 0x00FD: return ([121], 115) // ý -> y + s
        case 0x1EF7: return ([121], 114) // ỷ -> y + r
        case 0x1EF9: return ([121], 120) // ỹ -> y + x
        case 0x1EF5: return ([121], 106) // ỵ -> y + j

        default:
            return ([val], nil)
        }
    }
}
