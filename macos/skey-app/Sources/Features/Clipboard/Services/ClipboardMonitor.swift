import AppKit
import CryptoKit
import Foundation

// MARK: - ClipboardMonitor

/// Detects new clipboard content by polling NSPasteboard.general.changeCount on a background timer
public final class ClipboardMonitor: @unchecked Sendable {
    public static let shared = ClipboardMonitor()

    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int
    private var onCapture: (@Sendable (CapturedClipboardContent) -> Void)?
    private let captureQueue = DispatchQueue(label: "com.nam088.skey.clipboard.capture", qos: .utility)

    public init(pollInterval: TimeInterval = 0.5) {
        self.pollInterval = pollInterval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func startMonitoring(onCapture: @escaping @Sendable (CapturedClipboardContent) -> Void) {
        stopMonitoring()
        self.onCapture = onCapture
        self.lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        onCapture = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Pasteboard capture may decode RTF/images and hash megabytes of data.
        // Keep the polling callback short and move expensive work off the main run loop.
        let callback = onCapture
        captureQueue.async {
            guard let captured = Self.capture(from: pasteboard) else { return }
            callback?(captured)
        }
    }

    public static func capture(from pasteboard: NSPasteboard) -> CapturedClipboardContent? {
        let markers = Set((pasteboard.types ?? []).map(\.rawValue))
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // 1. Files
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let fileURL = fileURLs.first, fileURL.isFileURL {
            let payload = try? Data(contentsOf: fileURL)
            let size = payload?.count
                ?? ((try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0)
            return CapturedClipboardContent(
                contentType: .fileReference,
                contentHash: sha256Hex(Data(fileURL.path.utf8)),
                textContent: fileURL.lastPathComponent,
                payloadData: payload,
                payloadSizeBytes: size,
                sourceBundleID: sourceBundleID,
                pasteboardTypeMarkers: markers
            )
        }

        // 2. Text / Rich Text (Prioritized: rich editors often attach redundant TIFF/PNG preview blobs)
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let rtf = pasteboard.data(forType: .rtf) {
                return CapturedClipboardContent(
                    contentType: .richText,
                    contentHash: sha256Hex(Data(string.utf8)),
                    textContent: string,
                    payloadData: rtf,
                    payloadSizeBytes: rtf.count,
                    sourceBundleID: sourceBundleID,
                    pasteboardTypeMarkers: markers
                )
            } else {
                let data = Data(string.utf8)
                return CapturedClipboardContent(
                    contentType: .plainText,
                    contentHash: sha256Hex(data),
                    textContent: string,
                    payloadData: nil,
                    payloadSizeBytes: data.count,
                    sourceBundleID: sourceBundleID,
                    pasteboardTypeMarkers: markers
                )
            }
        }

        // 3. RTF without plain text
        if let rtf = pasteboard.data(forType: .rtf) {
            let plain = (try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string) ?? ""
            if !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return CapturedClipboardContent(
                    contentType: .richText,
                    contentHash: sha256Hex(rtf),
                    textContent: plain,
                    payloadData: rtf,
                    payloadSizeBytes: rtf.count,
                    sourceBundleID: sourceBundleID,
                    pasteboardTypeMarkers: markers
                )
            }
        }

        // 4. Standalone Images (Screenshots, copied image files from Preview/Finder)
        if let pngData = pasteboard.data(forType: .png) {
            return CapturedClipboardContent(
                contentType: .image,
                contentHash: sha256Hex(pngData),
                textContent: nil,
                payloadData: pngData,
                payloadSizeBytes: pngData.count,
                sourceBundleID: sourceBundleID,
                pasteboardTypeMarkers: markers
            )
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            let finalData: Data
            if let imageRep = NSBitmapImageRep(data: tiffData),
               let compressedPng = imageRep.representation(using: .png, properties: [:]) {
                finalData = compressedPng
            } else {
                finalData = tiffData
            }
            return CapturedClipboardContent(
                contentType: .image,
                contentHash: sha256Hex(finalData),
                textContent: nil,
                payloadData: finalData,
                payloadSizeBytes: finalData.count,
                sourceBundleID: sourceBundleID,
                pasteboardTypeMarkers: markers
            )
        }

        // 5. Plain text fallback
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let data = Data(string.utf8)
            return CapturedClipboardContent(
                contentType: .plainText,
                contentHash: sha256Hex(data),
                textContent: string,
                payloadData: nil,
                payloadSizeBytes: data.count,
                sourceBundleID: sourceBundleID,
                pasteboardTypeMarkers: markers
            )
        }

        return nil
    }

    public static func copyToPasteboard(_ item: ClipboardItem, payloadData: Data? = nil, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if asPlainText || item.contentType == .plainText {
            if let text = item.textContent ?? (item.previewText.isEmpty ? nil : item.previewText) {
                pasteboard.setString(text, forType: .string)
            }
            return
        }

        switch item.contentType {
        case .plainText:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            if let rtfData = payloadData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let imageData = payloadData {
                pasteboard.setData(imageData, forType: .png)
            }
        case .fileReference:
            if let path = item.textContent {
                let url = URL(fileURLWithPath: path)
                pasteboard.writeObjects([url as NSURL])
            }
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
