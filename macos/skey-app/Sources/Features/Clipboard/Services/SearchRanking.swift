import Foundation

// MARK: - SearchRanking

/// Incremental search and scoring algorithm over clipboard items
public struct SearchRanking: Sendable {
    public init() {}

    public func rank(
        _ items: [ClipboardItem],
        matchingNormalized normalizedQuery: String,
        original: String
    ) -> [ClipboardItem] {
        guard !normalizedQuery.isEmpty else { return items }

        let exactLower = original.lowercased()

        return items
            .compactMap { item -> (ClipboardItem, Int)? in
                guard let score = Self.score(
                    normalizedHaystack: item.normalizedSearchText,
                    exactQuery: exactLower,
                    normalizedQuery: normalizedQuery
                ) else { return nil }
                return (item, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private static func score(
        normalizedHaystack: String,
        exactQuery: String,
        normalizedQuery: String
    ) -> Int? {
        // 1. Exact case substring match — highest priority
        if let range = normalizedHaystack.range(of: exactQuery) {
            let position = normalizedHaystack.distance(from: normalizedHaystack.startIndex, to: range.lowerBound)
            return 2_000_000 - position
        }

        // 2. Normalised (diacritic-insensitive) substring match
        if let range = normalizedHaystack.range(of: normalizedQuery) {
            let position = normalizedHaystack.distance(from: normalizedHaystack.startIndex, to: range.lowerBound)
            return 1_000_000 - position
        }

        // 3. Subsequence match — lowest rank but still a match
        if isSubsequence(normalizedQuery, of: normalizedHaystack) {
            return 0
        }

        return nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = Substring(needle)
        for char in haystack {
            guard let first = remaining.first else { break }
            if char == first { remaining.removeFirst() }
        }
        return remaining.isEmpty
    }
}
