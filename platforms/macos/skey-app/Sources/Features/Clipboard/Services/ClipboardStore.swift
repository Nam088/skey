import Foundation

// MARK: - ClipboardStore Actor

public actor ClipboardStore {
    private let policy: ClipboardRetentionPolicy
    private let repository: ClipboardRepository
    private let payloadStore: PayloadStoring
    private let sortOrderProvider: @Sendable () -> ClipboardSortOrder
    private let pinPlacementProvider: @Sendable () -> ClipboardPinTo

    public nonisolated let events: AsyncStream<ClipboardEvent>
    private let eventContinuation: AsyncStream<ClipboardEvent>.Continuation

    private var isPaused = false
    private var cachedItems: [ClipboardItem] = []
    private var isCacheLoaded = false

    public init(
        policy: ClipboardRetentionPolicy = ClipboardRetentionPolicy(),
        repository: ClipboardRepository? = nil,
        payloadStore: PayloadStoring = FileSystemPayloadStore(),
        sortOrderProvider: @escaping @Sendable () -> ClipboardSortOrder = { AppSettings.shared.clipboard.sortOrder },
        pinPlacementProvider: @escaping @Sendable () -> ClipboardPinTo = { AppSettings.shared.clipboard.pinTo }
    ) {
        let repo: ClipboardRepository
        if let injected = repository {
            repo = injected
        } else {
            repo = (try? SQLiteClipboardRepository()) ?? InMemoryClipboardRepository()
        }
        self.policy = policy
        self.repository = repo
        self.payloadStore = payloadStore
        self.sortOrderProvider = sortOrderProvider
        self.pinPlacementProvider = pinPlacementProvider

        let (stream, continuation) = AsyncStream.makeStream(of: ClipboardEvent.self)
        self.events = stream
        self.eventContinuation = continuation

        Task(priority: .userInitiated) { [repo] in
            try? await repo.backfillNormalizedSearchText()
            let items = (try? await repo.fetchAllForPolicyEvaluation()) ?? []
            await self.setInitialCache(items)
        }
    }

    private func setInitialCache(_ items: [ClipboardItem]) {
        self.cachedItems = Self.applyPinOrder(Self.applySortOrder(sortOrderProvider(), to: items), pinTo: pinPlacementProvider())
        self.isCacheLoaded = true
    }

    public func getCachedItems() -> [ClipboardItem] {
        return cachedItems
    }

    public func setPaused(_ paused: Bool) {
        self.isPaused = paused
    }

    public func togglePaused() -> Bool {
        self.isPaused.toggle()
        return self.isPaused
    }

    public func getIsPaused() -> Bool {
        self.isPaused
    }

    public func capture(_ candidate: CapturedClipboardContent) async throws {
        guard !isPaused else { return }
        let existing = isCacheLoaded ? cachedItems : try await repository.fetchAllForPolicyEvaluation()
        let decision = policy.decide(candidate, existing: existing)

        switch decision {
        case .skip:
            return

        case .bumpExisting(let itemID):
            try await repository.bumpToTop(itemID: itemID)
            if let idx = cachedItems.firstIndex(where: { $0.id == itemID }) {
                var item = cachedItems.remove(at: idx)
                item.capturedAt = Date()
                item.copyCount += 1
                cachedItems.insert(item, at: 0)
                // Bumping changes visible metadata (timestamp/count), so observers
                // must receive an update even though no new row was inserted.
                eventContinuation.yield(.updated(item))
            }

        case .retainFull, .retainMetadataOnly:
            var payloadPath: String?
            var hasFullPayload = false
            var payloadSizeBytes = candidate.payloadSizeBytes
            if decision == .retainFull {
                if let data = candidate.payloadData {
                    if let path = try? payloadStore.write(data) {
                        payloadPath = path
                        hasFullPayload = true
                        // The captured byte count can be absent for pasteboard
                        // providers; persist the authoritative payload size.
                        payloadSizeBytes = data.count
                    }
                }
            }

            let item = ClipboardItem(
                contentType: candidate.contentType,
                contentHash: candidate.contentHash,
                textContent: candidate.textContent,
                payloadPath: payloadPath,
                payloadSizeBytes: payloadSizeBytes,
                hasFullPayload: hasFullPayload,
                previewText: Self.derivePreview(candidate),
                sourceBundleID: candidate.sourceBundleID,
                capturedAt: Date()
            )
            try await repository.insert(item)
            cachedItems.insert(item, at: 0)
            eventContinuation.yield(.added(item))

            if AppSettings.shared.clipboard.autoExpireOTP, Self.isSensitiveOTP(candidate.textContent) {
                Task { [weak self, itemID = item.id] in
                    try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                    try? await self?.delete(itemID: itemID)
                }
            }

            try await pruneIfNeeded(knownExisting: existing + [item])
        }
    }

    public static func isSensitiveOTP(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return false }
        let isDigits = text.allSatisfy({ $0.isNumber })
        return isDigits && (text.count == 6 || text.count == 4 || text.count == 8)
    }

    public func fetchHistory(matching query: String) async throws -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && isCacheLoaded {
            let ordered = Self.applySortOrder(sortOrderProvider(), to: cachedItems)
            return Self.applyPinOrder(ordered, pinTo: pinPlacementProvider())
        }

        let normalizedQuery = ClipboardItem.vietnameseFold(trimmed)
        let candidates = try await repository.fetchAll(matching: normalizedQuery)
        if trimmed.isEmpty && !isCacheLoaded {
            setInitialCache(candidates)
        }
        let ranked = SearchRanking().rank(candidates, matchingNormalized: normalizedQuery, original: query)

        let ordered = trimmed.isEmpty
            ? Self.applySortOrder(sortOrderProvider(), to: ranked)
            : ranked

        return Self.applyPinOrder(ordered, pinTo: pinPlacementProvider())
    }

    private static func applySortOrder(_ order: ClipboardSortOrder, to items: [ClipboardItem]) -> [ClipboardItem] {
        switch order {
        case .lastCopiedAt:
            return items
        case .firstCopiedAt:
            return items.sorted {
                if $0.firstCopiedAt != $1.firstCopiedAt { return $0.firstCopiedAt > $1.firstCopiedAt }
                return $0.capturedAt > $1.capturedAt
            }
        case .numberOfCopies:
            return items.sorted {
                if $0.copyCount != $1.copyCount { return $0.copyCount > $1.copyCount }
                return $0.capturedAt > $1.capturedAt
            }
        }
    }

    /// Applies pin placement while preserving the order produced by the selected sort.
    /// Kept pure so ordering regressions can be tested without an actor or AppKit.
    public static func applyPinOrder(_ items: [ClipboardItem], pinTo: ClipboardPinTo) -> [ClipboardItem] {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        return pinTo == .bottom ? unpinned + pinned : pinned + unpinned
    }

    public func togglePin(itemID: UUID) async throws {
        let existing = isCacheLoaded ? cachedItems : try await repository.fetchAllForPolicyEvaluation()
        guard let item = existing.first(where: { $0.id == itemID }) else { return }
        let newValue = !item.isPinned
        try await repository.setPinned(itemID: itemID, isPinned: newValue)
        if let idx = cachedItems.firstIndex(where: { $0.id == itemID }) {
            cachedItems[idx].isPinned = newValue
        }
        var updated = item
        updated.isPinned = newValue
        eventContinuation.yield(.updated(updated))
    }

    public func loadPayloadData(for item: ClipboardItem) async -> Data? {
        guard item.hasFullPayload, let path = item.payloadPath else { return nil }
        return try? payloadStore.read(at: path)
    }

    public func delete(itemID: UUID) async throws {
        let existing = isCacheLoaded ? cachedItems : try await repository.fetchAllForPolicyEvaluation()
        if let item = existing.first(where: { $0.id == itemID }) {
            payloadStore.delete(at: item.payloadPath)
        }
        try await repository.delete(itemID: itemID)
        cachedItems.removeAll(where: { $0.id == itemID })
        eventContinuation.yield(.removed(itemID: itemID))
    }

    public func clearAll() async throws {
        let items = isCacheLoaded ? cachedItems : try await repository.fetchAllForPolicyEvaluation()
        for item in items {
            payloadStore.delete(at: item.payloadPath)
        }
        try await repository.deleteAll()
        cachedItems.removeAll()
        eventContinuation.yield(.clearedAll)
    }

    public func clearUnpinned() async throws {
        let items = isCacheLoaded ? cachedItems : try await repository.fetchAllForPolicyEvaluation()
        for item in items where !item.isPinned {
            payloadStore.delete(at: item.payloadPath)
            try await repository.delete(itemID: item.id)
            eventContinuation.yield(.removed(itemID: item.id))
        }
        cachedItems.removeAll(where: { !$0.isPinned })
    }

    private func pruneIfNeeded(knownExisting: [ClipboardItem]) async throws {
        let toPrune = policy.itemsToPrune(existing: knownExisting)
        guard !toPrune.isEmpty else { return }

        let pruneSet = Set(toPrune)
        let byID = Dictionary(knownExisting.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in toPrune {
            if let item = byID[id] {
                payloadStore.delete(at: item.payloadPath)
            }
            try await repository.delete(itemID: id)
            eventContinuation.yield(.removed(itemID: id))
        }
        cachedItems.removeAll(where: { pruneSet.contains($0.id) })
    }

    private static func derivePreview(_ candidate: CapturedClipboardContent) -> String {
        switch candidate.contentType {
        case .plainText, .richText:
            let raw = candidate.textContent ?? ""
            let lines = raw.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let preview = lines.joined(separator: " ")
            return String(preview.prefix(200))
        case .image:
            let size = ByteCountFormatter.string(fromByteCount: Int64(candidate.payloadSizeBytes), countStyle: .file)
            return "Image (\(size))"
        case .fileReference:
            return candidate.textContent ?? "File"
        }
    }
}

// MARK: - InMemory Fallback Repository

actor InMemoryClipboardRepository: ClipboardRepository {
    private var items: [ClipboardItem] = []

    init() {}

    func insert(_ item: ClipboardItem) async throws {
        items.removeAll(where: { $0.id == item.id })
        items.insert(item, at: 0)
    }

    func fetchAll(matching query: String) async throws -> [ClipboardItem] {
        if query.isEmpty { return items }
        return items.filter { $0.normalizedSearchText.contains(query) }
    }

    func fetchAllForPolicyEvaluation() async throws -> [ClipboardItem] {
        items
    }

    func bumpToTop(itemID: UUID) async throws {
        if let idx = items.firstIndex(where: { $0.id == itemID }) {
            var item = items.remove(at: idx)
            item.capturedAt = Date()
            item.copyCount += 1
            items.insert(item, at: 0)
        }
    }

    func setPinned(itemID: UUID, isPinned: Bool) async throws {
        if let idx = items.firstIndex(where: { $0.id == itemID }) {
            items[idx].isPinned = isPinned
        }
    }

    func delete(itemID: UUID) async throws {
        items.removeAll(where: { $0.id == itemID })
    }

    func deleteAll() async throws {
        items.removeAll()
    }

    func backfillNormalizedSearchText() async throws {}
}
