import Foundation

// MARK: - ClipboardItem

/// A single captured clipboard entry with full metadata, search index, and payload support
public struct ClipboardItem: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public var contentType: ClipboardContentType
    public var contentHash: String
    public var textContent: String?
    public var payloadPath: String?
    public var payloadSizeBytes: Int
    public var hasFullPayload: Bool
    public var previewText: String
    public var sourceBundleID: String?
    public var capturedAt: Date
    public var isPinned: Bool
    public var firstCopiedAt: Date
    public var copyCount: Int
    public var normalizedSearchText: String

    public init(
        id: UUID = UUID(),
        contentType: ClipboardContentType,
        contentHash: String,
        textContent: String? = nil,
        payloadPath: String? = nil,
        payloadSizeBytes: Int = 0,
        hasFullPayload: Bool,
        previewText: String,
        sourceBundleID: String? = nil,
        capturedAt: Date,
        isPinned: Bool = false,
        firstCopiedAt: Date? = nil,
        copyCount: Int = 1
    ) {
        self.id = id
        self.contentType = contentType
        self.contentHash = contentHash
        self.textContent = textContent
        self.payloadPath = payloadPath
        self.payloadSizeBytes = payloadSizeBytes
        self.hasFullPayload = hasFullPayload
        self.previewText = previewText
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
        self.isPinned = isPinned
        self.firstCopiedAt = firstCopiedAt ?? capturedAt
        self.copyCount = copyCount
        
        let raw = "\(textContent ?? "") \(previewText)"
        self.normalizedSearchText = Self.vietnameseFold(raw)
    }

    /// Normalises string for diacritic-insensitive search (replaces Đ/đ -> D/d first)
    public static func vietnameseFold(_ string: String) -> String {
        string
            .replacingOccurrences(of: "Đ", with: "D")
            .replacingOccurrences(of: "đ", with: "d")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

// MARK: - CapturedClipboardContent

/// Raw candidate captured from NSPasteboard before retention decision
public struct CapturedClipboardContent: Sendable {
    public let contentType: ClipboardContentType
    public let contentHash: String
    public let textContent: String?
    public let payloadData: Data?
    public let payloadSizeBytes: Int
    public let sourceBundleID: String?
    public let pasteboardTypeMarkers: Set<String>

    public init(
        contentType: ClipboardContentType,
        contentHash: String,
        textContent: String? = nil,
        payloadData: Data? = nil,
        payloadSizeBytes: Int = 0,
        sourceBundleID: String? = nil,
        pasteboardTypeMarkers: Set<String> = []
    ) {
        self.contentType = contentType
        self.contentHash = contentHash
        self.textContent = textContent
        self.payloadData = payloadData
        self.payloadSizeBytes = payloadSizeBytes
        self.sourceBundleID = sourceBundleID
        self.pasteboardTypeMarkers = pasteboardTypeMarkers
    }
}
