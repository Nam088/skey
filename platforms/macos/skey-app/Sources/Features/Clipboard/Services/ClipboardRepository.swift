import Foundation

// MARK: - ClipboardRepository Protocol

public protocol ClipboardRepository: Sendable {
    func insert(_ item: ClipboardItem) async throws
    func fetchAll(matching query: String) async throws -> [ClipboardItem]
    func fetchAllForPolicyEvaluation() async throws -> [ClipboardItem]
    func bumpToTop(itemID: UUID) async throws
    func setPinned(itemID: UUID, isPinned: Bool) async throws
    func delete(itemID: UUID) async throws
    func deleteAll() async throws
    func backfillNormalizedSearchText() async throws
}
