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

    public func shape(cornerRadius: CGFloat) -> SelectionShape {
        SelectionShape(appearance: self, cornerRadius: cornerRadius)
    }
}

public struct SelectionShape: Shape {
    public var appearance: SelectionAppearance
    public var cornerRadius: CGFloat

    public func path(in rect: CGRect) -> Path {
        let tl: CGFloat = (appearance == .none || appearance == .bottomConnection) ? cornerRadius : 0
        let tr: CGFloat = (appearance == .none || appearance == .bottomConnection) ? cornerRadius : 0
        let bl: CGFloat = (appearance == .none || appearance == .topConnection) ? cornerRadius : 0
        let br: CGFloat = (appearance == .none || appearance == .topConnection) ? cornerRadius : 0

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        path.closeSubpath()
        return path
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
