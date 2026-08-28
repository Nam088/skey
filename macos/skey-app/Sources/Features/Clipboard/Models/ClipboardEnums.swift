import AppKit
import Foundation
import SwiftUI

// MARK: - Clipboard Content Type

public enum ClipboardContentType: String, Codable, Sendable, Equatable {
    case plainText
    case richText
    case image
    case fileReference
}

// MARK: - Clipboard Preview Placement

public enum ClipboardPreviewPlacement: Sendable {
    case left
    case right
}

// MARK: - Selection Appearance (Multi-selection & Connected Rows)

public enum SelectionAppearance: Sendable {
    case none
    case topConnection
    case bottomConnection
    case topBottomConnection

    public func rect(cornerRadius: CGFloat) -> AnyShape {
        switch self {
        case .none:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: cornerRadius
            ))
        case .topConnection:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 0
            ))
        case .bottomConnection:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: cornerRadius
            ))
        case .topBottomConnection:
            return AnyShape(Rectangle())
        }
    }
}

// MARK: - Retention Decision

public enum RetentionDecision: Sendable, Equatable {
    case skip
    case bumpExisting(itemID: UUID)
    case retainFull
    case retainMetadataOnly
}

// MARK: - Clipboard Event (Actor Stream)

public enum ClipboardEvent: Sendable {
    case added(ClipboardItem)
    case removed(itemID: UUID)
    case clearedAll
    case updated(ClipboardItem)
}

// MARK: - Exclusion Rule

public struct ExclusionRule: Sendable, Codable, Equatable {
    public let bundleID: String
    public init(bundleID: String) {
        self.bundleID = bundleID
    }
}
