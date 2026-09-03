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

// MARK: - MacroConstant Model

/// Represents a user-defined custom constant variable for macro templates.
/// Example: key = "email", value = "nam@company.com" -> token is "{$email}"
public struct MacroConstant: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var key: String
    public var value: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.createdAt = createdAt
    }

    /// The template token representation, e.g. "{$email}"
    public var token: String {
        "{$" + key + "}"
    }
}
