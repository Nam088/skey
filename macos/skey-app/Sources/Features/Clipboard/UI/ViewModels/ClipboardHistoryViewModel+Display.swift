import AppKit
import Foundation
import SwiftUI

// MARK: - Row Presentation & Display Helpers

public extension ClipboardHistoryViewModel {

    func cachedThumbnail(for item: ClipboardItem) -> NSImage? {
        imageCache.object(forKey: item.id as NSUUID)
    }

    func fullImage(for item: ClipboardItem) async -> NSImage? {
        if let cached = imageCache.object(forKey: item.id as NSUUID) { return cached }
        guard item.hasFullPayload, let data = await store.loadPayloadData(for: item), let image = NSImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: item.id as NSUUID)
        return image
    }

    func attributedTitle(for item: ClipboardItem) -> AttributedString {
        let key = "\(item.id.uuidString)|\(searchQuery)|\(settings.highlightMatch.rawValue)" as NSString
        if let cached = attributedTitleCache.object(forKey: key) {
            return AttributedString(cached)
        }

        var raw = item.previewText
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let text = item.textContent {
            raw = text
        }
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var cleanTitle = lines.joined(separator: " ")
        if cleanTitle.isEmpty {
            cleanTitle = item.contentType == .image ? "Image" : "..."
        }

        let title = String(cleanTitle.prefix(500))
        var attributed = AttributedString(title)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !title.isEmpty else {
            attributedTitleCache.setObject(NSAttributedString(attributed), forKey: key)
            return attributed
        }

        let loweredTitle = title.lowercased()
        let loweredQuery = query.lowercased()
        var searchStart = loweredTitle.startIndex
        while let range = loweredTitle.range(of: loweredQuery, range: searchStart..<loweredTitle.endIndex) {
            defer { searchStart = range.upperBound }
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            switch settings.highlightMatch {
            case .bold:
                attributed[lower..<upper].font = .body.bold()
            case .italic:
                attributed[lower..<upper].font = .body.italic()
            case .underline:
                attributed[lower..<upper].underlineStyle = .single
            case .color:
                attributed[lower..<upper].backgroundColor = Color(nsColor: .findHighlightColor)
                attributed[lower..<upper].foregroundColor = .black
            }
        }
        attributedTitleCache.setObject(NSAttributedString(attributed), forKey: key)
        return attributed
    }

    func appIcon(for bundleID: String?) -> NSImage? {
        guard settings.showApplicationIcons, let bundleID else { return nil }
        if missingAppIcons.contains(bundleID) { return nil }
        if let hit = appIconCache.object(forKey: bundleID as NSString) { return hit }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missingAppIcons.insert(bundleID)
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 15, height: 15)
        appIconCache.setObject(icon, forKey: bundleID as NSString)
        return icon
    }

    func appName(for bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        if let hit = appNameCache.object(forKey: bundleID as NSString) { return hit as String }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        appNameCache.setObject(name as NSString, forKey: bundleID as NSString)
        return name
    }

    func colorSwatch(for item: ClipboardItem) -> NSImage? {
        guard settings.showHexColorSwatch, item.contentType != .image else { return nil }
        let text = item.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("#") || text.hasPrefix("0x") || (text.count >= 3 && text.count <= 8 && text.allSatisfy(\.isHexDigit)) else {
            return nil
        }
        let key = text as NSString
        if let hit = colorSwatchCache.object(forKey: key) { return hit }
        guard let image = ColorImage.from(text) else { return nil }
        colorSwatchCache.setObject(image, forKey: key)
        return image
    }
}
