import XCTest
@testable import SKey

final class ClipboardStoreTests: XCTestCase {
    private func item(_ id: UUID, pinned: Bool, captured: TimeInterval) -> ClipboardItem {
        ClipboardItem(
            id: id,
            contentType: .plainText,
            contentHash: id.uuidString,
            textContent: id.uuidString,
            hasFullPayload: false,
            previewText: id.uuidString,
            capturedAt: Date(timeIntervalSince1970: captured),
            isPinned: pinned
        )
    }

    func testPinOrderTopAndBottomPreservesSortOrder() {
        let first = UUID(), second = UUID(), third = UUID()
        let input = [item(first, pinned: false, captured: 3), item(second, pinned: true, captured: 2), item(third, pinned: true, captured: 1)]

        XCTAssertEqual(ClipboardStore.applyPinOrder(input, pinTo: .top).map(\.id), [second, third, first])
        XCTAssertEqual(ClipboardStore.applyPinOrder(input, pinTo: .bottom).map(\.id), [first, second, third])
    }
}
