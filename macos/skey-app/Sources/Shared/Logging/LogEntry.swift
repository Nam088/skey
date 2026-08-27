import Foundation

// MARK: - LogLevel

public enum LogLevel: String, CaseIterable, Codable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARN"
    case error   = "ERROR"
}

// MARK: - LogCategory

public enum LogCategory: String, CaseIterable, Codable {
    case app         = "App"
    case keyboard    = "Keyboard"
    case clipboard   = "Clipboard"
    case permissions = "Permissions"
    case engine      = "Engine"
    case ui          = "UI"
    case general     = "General"
}

// MARK: - LogEntry

public struct LogEntry: Identifiable, Equatable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String
    public let line: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel = .info,
        category: LogCategory = .general,
        message: String,
        file: String = #file,
        line: Int = #line
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.line = line
    }

    public var formattedString: String {
        let timeStr = DateFormatter.logTimeFormatter.string(from: timestamp)
        return "\(timeStr) [\(level.rawValue)] [\(category.rawValue)] \(message)"
    }
}

// MARK: - DateFormatter Helper

extension DateFormatter {
    fileprivate static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
