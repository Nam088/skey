import Foundation

// MARK: - PayloadStoring Protocol

public protocol PayloadStoring: Sendable {
    func write(_ data: Data) throws -> String
    func delete(at path: String?)
    func read(at path: String) throws -> Data
}

// MARK: - FileSystemPayloadStore

public final class FileSystemPayloadStore: PayloadStoring {
    private let directoryURL: URL

    public init(directoryURL: URL? = nil) {
        if let dir = directoryURL {
            self.directoryURL = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directoryURL = appSupport.appendingPathComponent("com.nam088.skey/ClipboardPayloads")
        }
        try? FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    public func write(_ data: Data) throws -> String {
        let fileName = UUID().uuidString
        let url = directoryURL.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    public func delete(at path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(path))
    }

    public func read(at path: String) throws -> Data {
        try Data(contentsOf: directoryURL.appendingPathComponent(path))
    }
}
