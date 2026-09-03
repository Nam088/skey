import XCTest
@testable import SKey

final class SQLiteClipboardRepositoryTests: XCTestCase {
    var tempDBURL: URL!
    var repository: SQLiteClipboardRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory
        tempDBURL = tempDir.appendingPathComponent("test_clipboard_\(UUID().uuidString).sqlite3")
        repository = try SQLiteClipboardRepository(databaseURL: tempDBURL)
    }

    override func tearDownWithError() throws {
        repository = nil
        if let url = tempDBURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }

    func testInsertAndFetchClipboardItemPersistsStringsCorrectly() async throws {
        let itemID = UUID()
        let content = "Xin chào SKey Vietnamese Keyboard testing with special characters: 🇻🇳"
        let item = ClipboardItem(
            id: itemID,
            contentType: .plainText,
            contentHash: "hash123",
            textContent: content,
            payloadPath: "path/to/payload",
            payloadSizeBytes: 100,
            hasFullPayload: true,
            previewText: "Xin chào SKey...",
            sourceBundleID: "com.apple.Terminal",
            capturedAt: Date(),
            isPinned: false
        )

        try await repository.insert(item)

        let results = try await repository.fetchAll(matching: "")
        XCTAssertEqual(results.count, 1)
        let fetched = results[0]
        XCTAssertEqual(fetched.id, itemID)
        XCTAssertEqual(fetched.textContent, content)
        XCTAssertEqual(fetched.previewText, "Xin chào SKey...")
        XCTAssertEqual(fetched.sourceBundleID, "com.apple.Terminal")
        XCTAssertEqual(fetched.payloadPath, "path/to/payload")

        // Search test
        let searchResults = try await repository.fetchAll(matching: "SKey")
        XCTAssertEqual(searchResults.count, 1)

        // Bump test
        try await repository.bumpToTop(itemID: itemID)
        let bumpedResults = try await repository.fetchAll(matching: "")
        XCTAssertEqual(bumpedResults.first?.copyCount, 2)
    }
}
