import Foundation

// MARK: - ExcludedApp Model

public struct ExcludedApp: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { bundleID }
    public var bundleID: String
    public var name: String
    public var isEnabled: Bool

    public init(bundleID: String, name: String, isEnabled: Bool = true) {
        self.bundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
    }
}
