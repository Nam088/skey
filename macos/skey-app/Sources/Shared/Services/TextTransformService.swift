import AppKit
import Foundation

// MARK: - TextTransformService

public final class TextTransformService {
    public static let shared = TextTransformService()

    private init() {}

    public enum QuickAction: String, CaseIterable, Identifiable {
        case toUppercase
        case toLowercase
        case toTitleCase
        case removeTones
        case tcvn3ToUnicode
        case vniToUnicode
        case unicodeToTcvn3
        case unicodeToVni

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .toUppercase:     return L10n("tools.action.toUppercase")
            case .toLowercase:     return L10n("tools.action.toLowercase")
            case .toTitleCase:     return L10n("tools.action.toTitleCase")
            case .removeTones:     return L10n("tools.action.removeTones")
            case .tcvn3ToUnicode:  return L10n("tools.action.tcvn3ToUnicode")
            case .vniToUnicode:    return L10n("tools.action.vniToUnicode")
            case .unicodeToTcvn3:  return L10n("tools.action.unicodeToTcvn3")
            case .unicodeToVni:    return L10n("tools.action.unicodeToVni")
            }
        }

        public var icon: String {
            switch self {
            case .toUppercase:     return "textformat.size.larger"
            case .toLowercase:     return "textformat.size.smaller"
            case .toTitleCase:     return "textformat.size"
            case .removeTones:     return "character"
            case .tcvn3ToUnicode:  return "arrow.triangle.swap"
            case .vniToUnicode:    return "arrow.triangle.swap"
            case .unicodeToTcvn3:  return "arrow.triangle.swap"
            case .unicodeToVni:    return "arrow.triangle.swap"
            }
        }
    }

    // MARK: - Clipboard Quick Action

    public func transformClipboard(action: QuickAction) -> Bool {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return false
        }

        let result = transform(text: text, action: action)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        return true
    }

    // MARK: - Transform Engine

    public func transform(text: String, action: QuickAction) -> String {
        switch action {
        case .toUppercase:
            return text.uppercased()
        case .toLowercase:
            return text.lowercased()
        case .toTitleCase:
            return text.capitalized
        case .removeTones:
            return removeVietnameseTones(from: text)
        case .tcvn3ToUnicode:
            return tcvn3ToUnicode(text)
        case .vniToUnicode:
            return vniToUnicode(text)
        case .unicodeToTcvn3:
            return unicodeToTcvn3(text)
        case .unicodeToVni:
            return unicodeToVni(text)
        }
    }

    // MARK: - Diacritics Removal

    public func removeVietnameseTones(from text: String) -> String {
        var result = text
        let toneMap: [String: String] = [
            "à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ": "a",
            "À|Á|Ạ|Ả|Ã|Â|Ầ|Ấ|Ậ|Ẩ|Ẫ|Ă|Ằ|Ắ|Ặ|Ẳ|Ẵ": "A",
            "è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ": "e",
            "È|É|Ẹ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ": "E",
            "ì|í|ị|ỉ|ĩ": "i",
            "Ì|Í|Ị|Ỉ|Ĩ": "I",
            "ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ": "o",
            "Ò|Ó|Ọ|Ỏ|Õ|Ô|Ồ|Ố|Ộ|Ổ|Ỗ|Ơ|Ờ|Ớ|Ợ|Ở|Ỡ": "O",
            "ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ": "u",
            "Ù|Ú|Ụ|Ủ|Ũ|Ư|Ừ|Ứ|Ự|Ử|Ữ": "U",
            "ỳ|ý|ỵ|ỷ|ỹ": "y",
            "Ỳ|Ý|Ỵ|Ỷ|Ỹ": "Y",
            "đ": "d",
            "Đ": "D"
        ]

        for (pattern, replacement) in toneMap {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
    }

    // MARK: - TCVN3 / ABC Converter

    private let tcvn3Map: [Character: Character] = [
        "µ": "à", "¸": "á", "¶": "ả", "·": "ã", "¹": "ạ",
        "¨": "ă", "»": "ằ", "¾": "ắ", "¼": "ẳ", "½": "ẵ", "Æ": "ặ",
        "©": "â", "Ç": "ầ", "Ê": "ấ", "È": "ẩ", "É": "ẫ", "Ë": "ậ",
        "Ì": "è", "Ð": "é", "Î": "ẻ", "Ï": "ẽ", "Ñ": "ẹ",
        "ª": "ê", "Ò": "ề", "Õ": "ế", "Ó": "ể", "Ô": "ễ", "Ö": "ệ",
        "×": "ì", "Ý": "í", "Ø": "ỉ", "Ü": "ĩ", "Þ": "ị",
        "ß": "ò", "ó": "ó", "á": "ỏ", "ã": "õ", "ä": "ọ",
        "«": "ô", "å": "ồ", "è": "ố", "æ": "ổ", "ç": "ỗ", "é": "ộ",
        "¬": "ơ", "ê": "ờ", "í": "ớ", "ë": "ở", "ì": "ỡ", "î": "ợ",
        "ï": "ù", "ú": "ú", "ñ": "ủ", "ò": "ũ", "ô": "ụ",
        "®": "đ", "§": "Đ"
    ]

    public func tcvn3ToUnicode(_ text: String) -> String {
        var output = ""
        for char in text {
            if let converted = tcvn3Map[char] {
                output.append(converted)
            } else {
                output.append(char)
            }
        }
        return output
    }

    public func unicodeToTcvn3(_ text: String) -> String {
        var reverseMap: [Character: Character] = [:]
        for (k, v) in tcvn3Map {
            reverseMap[v] = k
        }
        var output = ""
        for char in text {
            if let converted = reverseMap[char] {
                output.append(converted)
            } else {
                output.append(char)
            }
        }
        return output
    }

    // MARK: - VNI Windows Converter

    private let vniPairs: [(String, String)] = [
        ("aù", "á"), ("aà", "à"), ("aû", "ả"), ("aõ", "ã"), ("aï", "ạ"),
        ("aù", "ắ"), ("aè", "ằ"), ("aú", "ẳ"), ("aü", "ẵ"), ("aë", "ặ"),
        ("aá", "ấ"), ("aà", "ầ"), ("aå", "ẩ"), ("aã", "ẫ"), ("aä", "ậ"),
        ("eù", "é"), ("eà", "è"), ("eû", "ẻ"), ("eõ", "ẽ"), ("eï", "ẹ"),
        ("eá", "ế"), ("eà", "ề"), ("eå", "ể"), ("eã", "ễ"), ("eä", "ệ"),
        ("í", "í"), ("ì", "ì"), ("ỉ", "ỉ"), ("ĩ", "ĩ"), ("ị", "ị"),
        ("où", "ó"), ("oà", "ò"), ("oû", "ỏ"), ("oõ", "õ"), ("oï", "ọ"),
        ("oá", "ố"), ("oà", "ồ"), ("oå", "ổ"), ("oã", "ỗ"), ("oä", "ộ"),
        ("ôù", "ớ"), ("ôà", "ờ"), ("ôû", "ở"), ("ôõ", "ỡ"), ("ôï", "ợ"),
        ("uù", "ú"), ("uà", "ù"), ("uû", "ủ"), ("uõ", "ũ"), ("uï", "ụ"),
        ("öù", "ứ"), ("öà", "ừ"), ("öû", "ử"), ("öõ", "ữ"), ("öï", "ự"),
        ("yù", "ý"), ("yà", "ỳ"), ("yû", "ỷ"), ("yõ", "ỹ"), ("î", "ỵ"),
        ("ñ", "đ"), ("Ñ", "Đ")
    ]

    public func vniToUnicode(_ text: String) -> String {
        var output = text
        for (vni, uni) in vniPairs {
            output = output.replacingOccurrences(of: vni, with: uni)
        }
        return output
    }

    public func unicodeToVni(_ text: String) -> String {
        var output = text
        for (vni, uni) in vniPairs {
            output = output.replacingOccurrences(of: uni, with: vni)
        }
        return output
    }
}
