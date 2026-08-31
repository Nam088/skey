import Foundation

// MARK: - MacroItem Model

public struct MacroItem: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var shortcut: String
    public var replacement: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        shortcut: String,
        replacement: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shortcut = shortcut
        self.replacement = replacement
        self.createdAt = createdAt
    }
}
