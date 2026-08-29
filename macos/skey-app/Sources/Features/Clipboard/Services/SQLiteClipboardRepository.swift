import Foundation
import SQLite3

// MARK: - SQLiteClipboardRepository

public final class SQLiteClipboardRepository: ClipboardRepository, @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.nam088.skey.clipboard.db", qos: .userInitiated)

    public init(databaseURL: URL? = nil) throws {
        let url: URL
        if let customURL = databaseURL {
            url = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("com.nam088.skey")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("clipboard.sqlite3")
        }

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &dbPointer, flags, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(dbPointer))
            throw NSError(domain: "SQLiteClipboardRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: errmsg])
        }
        self.db = dbPointer

        // Enable WAL mode & fast synchronous for concurrent reads & crash safety
        execute("PRAGMA journal_mode = WAL;")
        execute("PRAGMA synchronous = NORMAL;")

        // Create table
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS clipboardItem (
            id TEXT PRIMARY KEY,
            contentType TEXT NOT NULL,
            contentHash TEXT NOT NULL,
            textContent TEXT,
            payloadPath TEXT,
            payloadSizeBytes INTEGER NOT NULL,
            hasFullPayload INTEGER NOT NULL,
            previewText TEXT NOT NULL,
            sourceBundleID TEXT,
            capturedAt DOUBLE NOT NULL,
            isPinned INTEGER NOT NULL DEFAULT 0,
            firstCopiedAt DOUBLE NOT NULL,
            copyCount INTEGER NOT NULL DEFAULT 1,
            normalizedSearchText TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS idx_clipboard_hash ON clipboardItem(contentHash);
        CREATE INDEX IF NOT EXISTS idx_clipboard_captured ON clipboardItem(capturedAt);
        """
        execute(createTableSQL)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func execute(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Insert

    public func insert(_ item: ClipboardItem) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let sql = """
                INSERT OR REPLACE INTO clipboardItem (
                    id, contentType, contentHash, textContent, payloadPath,
                    payloadSizeBytes, hasFullPayload, previewText, sourceBundleID,
                    capturedAt, isPinned, firstCopiedAt, copyCount, normalizedSearchText
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    // Use withCString for optimized C string conversion (avoids NSString bridge allocation)
                    item.id.uuidString.withCString { uuidPtr in
                        _ = sqlite3_bind_text(statement, 1, uuidPtr, -1, nil)
                    }
                    item.contentType.rawValue.withCString { typePtr in
                        _ = sqlite3_bind_text(statement, 2, typePtr, -1, nil)
                    }
                    item.contentHash.withCString { hashPtr in
                        _ = sqlite3_bind_text(statement, 3, hashPtr, -1, nil)
                    }
                    if let text = item.textContent {
                        text.withCString { textPtr in
                            _ = sqlite3_bind_text(statement, 4, textPtr, -1, nil)
                        }
                    } else {
                        sqlite3_bind_null(statement, 4)
                    }
                    if let path = item.payloadPath {
                        path.withCString { pathPtr in
                            _ = sqlite3_bind_text(statement, 5, pathPtr, -1, nil)
                        }
                    } else {
                        sqlite3_bind_null(statement, 5)
                    }
                    sqlite3_bind_int64(statement, 6, Int64(item.payloadSizeBytes))
                    sqlite3_bind_int(statement, 7, item.hasFullPayload ? 1 : 0)
                    item.previewText.withCString { previewPtr in
                        _ = sqlite3_bind_text(statement, 8, previewPtr, -1, nil)
                    }
                    if let source = item.sourceBundleID {
                        source.withCString { sourcePtr in
                            _ = sqlite3_bind_text(statement, 9, sourcePtr, -1, nil)
                        }
                    } else {
                        sqlite3_bind_null(statement, 9)
                    }
                    sqlite3_bind_double(statement, 10, item.capturedAt.timeIntervalSince1970)
                    sqlite3_bind_int(statement, 11, item.isPinned ? 1 : 0)
                    sqlite3_bind_double(statement, 12, item.firstCopiedAt.timeIntervalSince1970)
                    sqlite3_bind_int64(statement, 13, Int64(item.copyCount))
                    item.normalizedSearchText.withCString { searchPtr in
                        _ = sqlite3_bind_text(statement, 14, searchPtr, -1, nil)
                    }

                    if sqlite3_step(statement) != SQLITE_DONE {
                        let errmsg = String(cString: sqlite3_errmsg(self.db))
                        sqlite3_finalize(statement)
                        continuation.resume(throwing: NSError(domain: "SQLiteClipboardRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: errmsg]))
                        return
                    }
                    sqlite3_finalize(statement)
                    continuation.resume()
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db))
                    continuation.resume(throwing: NSError(domain: "SQLiteClipboardRepository", code: 3, userInfo: [NSLocalizedDescriptionKey: errmsg]))
                }
            }
        }
    }

    // MARK: - Fetch

    public func fetchAll(matching query: String) async throws -> [ClipboardItem] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClipboardItem], Error>) in
            queue.async {
                let sql: String
                if query.isEmpty {
                    sql = "SELECT id, contentType, contentHash, textContent, payloadPath, payloadSizeBytes, hasFullPayload, previewText, sourceBundleID, capturedAt, isPinned, firstCopiedAt, copyCount, normalizedSearchText FROM clipboardItem ORDER BY capturedAt DESC;"
                } else {
                    sql = "SELECT id, contentType, contentHash, textContent, payloadPath, payloadSizeBytes, hasFullPayload, previewText, sourceBundleID, capturedAt, isPinned, firstCopiedAt, copyCount, normalizedSearchText FROM clipboardItem WHERE normalizedSearchText LIKE ? ORDER BY capturedAt DESC;"
                }

                var statement: OpaquePointer?
                var results: [ClipboardItem] = []
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    if !query.isEmpty {
                        let pattern = "%\(query)%"
                        sqlite3_bind_text(statement, 1, (pattern as NSString).utf8String, -1, nil)
                    }
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let item = self.readRow(statement) {
                            results.append(item)
                        }
                    }
                    sqlite3_finalize(statement)
                    continuation.resume(returning: results)
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db))
                    continuation.resume(throwing: NSError(domain: "SQLiteClipboardRepository", code: 4, userInfo: [NSLocalizedDescriptionKey: errmsg]))
                }
            }
        }
    }

    public func fetchAllForPolicyEvaluation() async throws -> [ClipboardItem] {
        try await fetchAll(matching: "")
    }

    private func readRow(_ stmt: OpaquePointer?) -> ClipboardItem? {
        guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
              let id = UUID(uuidString: idStr),
              let typeStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
              let contentType = ClipboardContentType(rawValue: typeStr),
              let hash = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
              let preview = sqlite3_column_text(stmt, 7).map({ String(cString: $0) })
        else { return nil }

        let textContent = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let payloadPath = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let payloadSizeBytes = Int(sqlite3_column_int64(stmt, 5))
        let hasFullPayload = sqlite3_column_int(stmt, 6) != 0
        let sourceBundleID = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let capturedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
        let isPinned = sqlite3_column_int(stmt, 10) != 0
        let firstCopiedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 11))
        let copyCount = Int(sqlite3_column_int64(stmt, 12))
        let normalizedSearchText = sqlite3_column_text(stmt, 13).map { String(cString: $0) } ?? ""

        var item = ClipboardItem(
            id: id,
            contentType: contentType,
            contentHash: hash,
            textContent: textContent,
            payloadPath: payloadPath,
            payloadSizeBytes: payloadSizeBytes,
            hasFullPayload: hasFullPayload,
            previewText: preview,
            sourceBundleID: sourceBundleID,
            capturedAt: capturedAt,
            isPinned: isPinned,
            firstCopiedAt: firstCopiedAt,
            copyCount: copyCount
        )
        if !normalizedSearchText.isEmpty {
            item.normalizedSearchText = normalizedSearchText
        }
        return item
    }

    // MARK: - Mutations

    public func bumpToTop(itemID: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let sql = "UPDATE clipboardItem SET capturedAt = ?, copyCount = copyCount + 1 WHERE id = ?;"
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
                    sqlite3_bind_text(statement, 2, (itemID.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_step(statement)
                    sqlite3_finalize(statement)
                    continuation.resume()
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func setPinned(itemID: UUID, isPinned: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let sql = "UPDATE clipboardItem SET isPinned = ? WHERE id = ?;"
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_int(statement, 1, isPinned ? 1 : 0)
                    sqlite3_bind_text(statement, 2, (itemID.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_step(statement)
                    sqlite3_finalize(statement)
                    continuation.resume()
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func delete(itemID: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let sql = "DELETE FROM clipboardItem WHERE id = ?;"
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, (itemID.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_step(statement)
                    sqlite3_finalize(statement)
                    continuation.resume()
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func deleteAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.execute("DELETE FROM clipboardItem;")
                continuation.resume()
            }
        }
    }

    public func backfillNormalizedSearchText() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let sql = "SELECT id, textContent, previewText FROM clipboardItem WHERE normalizedSearchText = '';"
                var statement: OpaquePointer?
                var itemsToUpdate: [(String, String)] = []
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let idStr = sqlite3_column_text(statement, 0).map({ String(cString: $0) }) {
                            let text = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                            let preview = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                            let raw = "\(text) \(preview)"
                            let folded = ClipboardItem.vietnameseFold(raw)
                            itemsToUpdate.append((idStr, folded))
                        }
                    }
                    sqlite3_finalize(statement)
                }

                for (idStr, folded) in itemsToUpdate {
                    let updateSQL = "UPDATE clipboardItem SET normalizedSearchText = ? WHERE id = ?;"
                    var updateStmt: OpaquePointer?
                    if sqlite3_prepare_v2(self.db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK {
                        sqlite3_bind_text(updateStmt, 1, (folded as NSString).utf8String, -1, nil)
                        sqlite3_bind_text(updateStmt, 2, (idStr as NSString).utf8String, -1, nil)
                        sqlite3_step(updateStmt)
                        sqlite3_finalize(updateStmt)
                    }
                }
                continuation.resume()
            }
        }
    }
}
