import Foundation
import os.log

// MARK: - SKeyLogger

/// High-performance, non-blocking unified logger for SKey Super App.
/// - Apple Unified Logging (os.Logger)
/// - Asynchronous background file persistence
/// - In-memory live store for UI observation
public final class SKeyLogger {
    public static let shared = SKeyLogger()

    private let osLogger = os.Logger(subsystem: "com.nam088.skey", category: "General")
    private let logStore = LogStore.shared

    /// Dedicated low-priority queue for disk writing to avoid blocking realtime event taps
    private let fileQueue = DispatchQueue(label: "com.nam088.skey.logger.file", qos: .utility)
    public let logFilePath = "/tmp/skey.log"
    private let maxLogFileSize: UInt64 = 2 * 1024 * 1024 // 2 MB

    private init() {}

    // MARK: - Core Log Method

    public func log(
        level: LogLevel,
        category: LogCategory = .general,
        message: String,
        file: String = #file,
        line: Int = #line
    ) {
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            line: line
        )

        // 1. Apple Unified OSLog (Zero allocation when inactive, visible in Console.app)
        switch level {
        case .debug:
            osLogger.debug("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        case .info:
            osLogger.info("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        case .warning:
            osLogger.warning("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        case .error:
            osLogger.error("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        }

        // 2. In-memory buffer for real-time UI streaming
        logStore.append(entry)

        // 3. Asynchronous non-blocking file I/O
        let lineFormatted = "\(entry.formattedString)\n"
        fileQueue.async { [weak self] in
            self?.writeToFile(lineFormatted)
        }
    }

    // MARK: - Async File Writer

    private func writeToFile(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        let fileManager = FileManager.default
        let path = logFilePath

        if fileManager.fileExists(atPath: path) {
            // Check file size for rotation
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64, size > maxLogFileSize {
                // Truncate or rotate
                try? fileManager.removeItem(atPath: path)
            }
        }

        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

// MARK: - Global Convenience API

public enum SKeyLog {
    public static func debug(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        SKeyLogger.shared.log(level: .debug, category: category, message: message, file: file, line: line)
    }

    public static func info(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        SKeyLogger.shared.log(level: .info, category: category, message: message, file: file, line: line)
    }

    public static func warning(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        SKeyLogger.shared.log(level: .warning, category: category, message: message, file: file, line: line)
    }

    public static func error(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        SKeyLogger.shared.log(level: .error, category: category, message: message, file: file, line: line)
    }
}

/// Backwards-compatible global function
public func skeyLog(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
    SKeyLogger.shared.log(level: .info, category: category, message: message, file: file, line: line)
}
