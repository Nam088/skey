import Foundation

// MARK: - Notification Extension

extension Notification.Name {
    public static let skeyDidEmitLog = Notification.Name("com.nam088.skey.didEmitLog")
    public static let skeyLogStoreDidClear = Notification.Name("com.nam088.skey.logStoreDidClear")
}

// MARK: - LogStore

/// Thread-safe in-memory log store supporting real-time event broadcasting to UI components
public final class LogStore {
    public static let shared = LogStore()

    private let lock = NSLock()
    private var buffer: [LogEntry] = []
    public let maxCapacity: Int

    /// Observers registered for real-time streaming
    private var observers: [(UUID, (LogEntry) -> Void)] = []

    public init(capacity: Int = 500) {
        self.maxCapacity = capacity
        self.buffer.reserveCapacity(capacity)
    }

    // MARK: - Append

    public func append(_ entry: LogEntry) {
        lock.lock()
        if buffer.count >= maxCapacity {
            buffer.removeFirst()
        }
        buffer.append(entry)
        let currentObservers = self.observers
        lock.unlock()

        // Broadcast to NotificationCenter on main queue
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .skeyDidEmitLog,
                object: self,
                userInfo: ["entry": entry]
            )

            // Direct callbacks
            for (_, callback) in currentObservers {
                callback(entry)
            }
        }
    }

    // MARK: - Read & Query

    public func allEntries() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    public func entries(matching category: LogCategory) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.filter { $0.category == category }
    }

    public func entries(matching level: LogLevel) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.filter { $0.level == level }
    }

    public func clear() {
        lock.lock()
        buffer.removeAll(keepingCapacity: true)
        lock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .skeyLogStoreDidClear, object: self)
        }
    }

    // MARK: - Observation

    public func subscribe(_ observer: @escaping (LogEntry) -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        defer { lock.unlock() }
        observers.append((token, observer))
        return token
    }

    public func unsubscribe(_ token: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeAll(where: { $0.0 == token })
    }
}
