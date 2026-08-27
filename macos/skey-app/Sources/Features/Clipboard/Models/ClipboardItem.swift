import Foundation

// MARK: - ClipboardItem

public struct ClipboardItem: Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public var isPinned: Bool

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    /// Truncated preview suitable for menu display
    public var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        if trimmed.count <= 40 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 37)
        return "\(trimmed[..<index])..."
    }
}
