import Foundation

// MARK: - InputMethodType

public enum InputMethodType: Int32, CaseIterable {
    case telex       = 0
    case vni         = 1
    case viqr        = 2
    case simpleTelex = 5

    public var displayName: String {
        switch self {
        case .telex:       return "Telex"
        case .simpleTelex: return "Simple Telex"
        case .vni:         return "VNI"
        case .viqr:        return "VIQR"
        }
    }
}
