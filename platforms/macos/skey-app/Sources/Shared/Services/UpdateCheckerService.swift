import AppKit
import Foundation

// MARK: - Update State

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String, releaseNotes: String, htmlUrl: URL, downloadUrl: URL?)
    case downloading(progress: Double)
    case extracting
    case readyToRestart
    case error(String)
}

// MARK: - UpdateCheckerService

@MainActor
public final class UpdateCheckerService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = UpdateCheckerService()

    @Published public var state: UpdateState = .idle
    @Published public var lastCheckDate: Date? {
        didSet {
            if let date = lastCheckDate {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "SKey_LastUpdateCheck")
            }
        }
    }

    private let repoOwner = "Nam088"
    private let repoName = "skey"

    /// Tag prefix for macOS releases. The repo publishes Windows releases into the same
    /// repository under `win-v*`, and `/releases/latest` returns whichever was published most
    /// recently regardless of platform. Left unfiltered, a Windows release would be offered to
    /// macOS users, download link included.
    private let releaseTagPrefix = "mac-v"
    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?

    override private init() {
        super.init()
        let savedTime = UserDefaults.standard.double(forKey: "SKey_LastUpdateCheck")
        if savedTime > 0 {
            self.lastCheckDate = Date(timeIntervalSince1970: savedTime)
        }
    }

    // MARK: - Current App Version

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Check For Updates

    public func checkForUpdates(isManual: Bool = false) {
        // For background check: skip if checked within last 24 hours
        if !isManual {
            if let last = lastCheckDate, Date().timeIntervalSince(last) < 86400 {
                return
            }
        }

        state = .checking

        // List releases instead of asking for /releases/latest: that endpoint is
        // platform-blind and would hand macOS users whatever shipped last, Windows included.
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=30") else {
            state = .error("Invalid API URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("SKey-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    if isManual { self.state = .error("Không nhận được phản hồi từ máy chủ") }
                    else { self.state = .idle }
                    return
                }

                if httpResponse.statusCode == 404 {
                    // No releases yet
                    self.lastCheckDate = Date()
                    self.state = isManual ? .upToDate : .idle
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    if isManual { self.state = .error("Lỗi máy chủ: \(httpResponse.statusCode)") }
                    else { self.state = .idle }
                    return
                }

                guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    if isManual { self.state = .error("Dữ liệu phản hồi không hợp lệ") }
                    else { self.state = .idle }
                    return
                }

                let macRelease = Self.newestRelease(in: releases, tagPrefix: self.releaseTagPrefix)

                guard let json = macRelease,
                      let tagName = json["tag_name"] as? String,
                      let htmlUrlStr = json["html_url"] as? String,
                      let htmlUrl = URL(string: htmlUrlStr) else {
                    // No macOS release published yet is a normal state, not an error.
                    self.lastCheckDate = Date()
                    self.state = isManual ? .upToDate : .idle
                    return
                }

                self.lastCheckDate = Date()
                let releaseNotes = (json["body"] as? String) ?? ""
                let remoteVersion = tagName.hasPrefix(self.releaseTagPrefix)
                    ? String(tagName.dropFirst(self.releaseTagPrefix.count))
                    : tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

                // Find Universal Zip or DMG asset
                var downloadUrl: URL?
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let browserUrl = asset["browser_download_url"] as? String,
                           let url = URL(string: browserUrl) {
                            // Belt and braces: the release is already filtered to mac-v*, but a
                            // stray Windows asset attached there must never become the download.
                            let lowercased = name.lowercased()
                            if lowercased.contains("windows") || lowercased.hasSuffix(".msi") || lowercased.hasSuffix(".exe") {
                                continue
                            }
                            if name.hasSuffix(".zip") {
                                downloadUrl = url
                                break
                            } else if name.hasSuffix(".dmg") && downloadUrl == nil {
                                downloadUrl = url
                            }
                        }
                    }
                }

                if Self.compareSemVer(remote: remoteVersion, local: self.currentVersion) == .orderedDescending {
                    self.state = .updateAvailable(
                        version: remoteVersion,
                        releaseNotes: releaseNotes,
                        htmlUrl: htmlUrl,
                        downloadUrl: downloadUrl
                    )
                } else {
                    self.state = isManual ? .upToDate : .idle
                }
            } catch {
                if isManual {
                    self.state = .error("Lỗi kết nối: \(error.localizedDescription)")
                } else {
                    self.state = .idle
                }
            }
        }
    }

    // MARK: - Start Download & Auto Install

    public func startUpdate(downloadUrl: URL) {
        state = .downloading(progress: 0.0)

        let config = URLSessionConfiguration.default
        // Download callbacks perform archive extraction and filesystem work; keep
        // them off the main run loop so update installation never freezes the UI.
        let delegateQueue = OperationQueue()
        delegateQueue.qualityOfService = .utility
        delegateQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        self.downloadSession = session

        var request = URLRequest(url: downloadUrl)
        request.setValue("SKey-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        self.downloadTask = task
        task.resume()
    }

    // MARK: - URLSessionDownloadDelegate (nonisolated for Swift 6 concurrency)

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            Task { @MainActor in
                self.state = .downloading(progress: progress)
            }
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            self.state = .extracting
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SKeyUpdate")
        let zipPath = tempDir.appendingPathComponent("update.zip")
        let appDestination = "/Applications/SKey.app"

        do {
            try? FileManager.default.removeItem(at: tempDir)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: zipPath)

            // Unzip using ditto (preserves macOS permissions & symlinks)
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProcess.arguments = ["-xk", zipPath.path, tempDir.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            let extractedApp = tempDir.appendingPathComponent("SKey.app")
            guard FileManager.default.fileExists(atPath: extractedApp.path) else {
                Task { @MainActor in
                    self.state = .error("Không tìm thấy tệp SKey.app trong gói cập nhật")
                }
                return
            }

            Task { @MainActor in
                self.state = .readyToRestart
            }

            // Execute atomic update script in background and relaunch
            let scriptPath = tempDir.appendingPathComponent("relaunch.sh").path
            let scriptContent = """
            #!/bin/bash
            sleep 0.8
            rm -rf "\(appDestination)"
            cp -R "\(extractedApp.path)" "\(appDestination)"
            xattr -cr "\(appDestination)" 2>/dev/null || true
            open -a "\(appDestination)"
            """
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

            let relaunchProcess = Process()
            relaunchProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            relaunchProcess.arguments = [scriptPath]
            try relaunchProcess.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        } catch {
            Task { @MainActor in
                self.state = .error("Lỗi cài đặt: \(error.localizedDescription)")
            }
        }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.state = .error("Lỗi tải về: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Semantic Versioning Comparison

    /// Picks the highest-versioned published release carrying `tagPrefix`.
    ///
    /// Deliberately does not take the first match. GitHub's release list is not reliably
    /// ordered newest first: this repo's own listing returns win-v1.0.9, win-v1.0.10,
    /// mac-v1.0.9, mac-v1.0.10, so trusting position would pin the updater to 1.0.9 forever
    /// and hide every release after it. Drafts and pre-releases are skipped.
    nonisolated static func newestRelease(in releases: [[String: Any]], tagPrefix: String) -> [String: Any]? {
        var best: [String: Any]?
        var bestTag = ""

        for release in releases {
            guard let tag = release["tag_name"] as? String, tag.hasPrefix(tagPrefix) else { continue }
            let isDraft = (release["draft"] as? Bool) ?? false
            let isPrerelease = (release["prerelease"] as? Bool) ?? false
            guard !isDraft, !isPrerelease else { continue }
            guard !parseNumbers(tag).isEmpty else { continue }

            if best == nil || compareSemVer(remote: tag, local: bestTag) == .orderedDescending {
                best = release
                bestTag = tag
            }
        }
        return best
    }

    /// Extracts the dotted numeric version out of a tag name.
    ///
    /// Release tags in this repo are platform prefixed (`mac-v1.0.9`, `win-v1.0.8`), and the
    /// previous implementation split on `-` and kept the first piece, so `mac-v1.0.9` reduced
    /// to `mac` and parsed to an empty array. Every comparison then treated the remote as
    /// version 0 and reported "you are on the latest version", which disabled updates
    /// entirely: even `mac-v2.0.0` looked older than a local `1.0.6`.
    ///
    /// Accepts `1.0.9`, `v1.0.9`, `mac-v1.0.9` and `1.0.9-beta.2` alike. Pre-release suffixes
    /// are dropped, matching the previous intent.
    nonisolated static func parseNumbers(_ str: String) -> [Int] {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer the digits following the last "v" (`mac-v1.0.9`), else the first digit run.
        var start = trimmed.startIndex
        if let vIndex = trimmed.lastIndex(where: { $0 == "v" || $0 == "V" }) {
            let after = trimmed.index(after: vIndex)
            if after < trimmed.endIndex, trimmed[after].isNumber {
                start = after
            }
        }
        if start == trimmed.startIndex, let firstDigit = trimmed.firstIndex(where: { $0.isNumber }) {
            start = firstDigit
        }

        let core = trimmed[start...].components(separatedBy: "-").first ?? ""
        // Stop at the first non-numeric component so "1.0.x" yields [1, 0] rather than [1, 0]
        // silently skipping a component and comparing the wrong positions against each other.
        var numbers: [Int] = []
        for component in core.components(separatedBy: ".") {
            guard let value = Int(component) else { break }
            numbers.append(value)
        }
        return numbers
    }

    nonisolated public static func compareSemVer(remote: String, local: String) -> ComparisonResult {
        let r = parseNumbers(remote)
        let l = parseNumbers(local)

        // An unparseable side means we cannot honestly say anything about ordering, and
        // guessing "up to date" is how this silently disabled updates for everyone. Treat it
        // as equal so the caller reports no update rather than a wrong one.
        guard !r.isEmpty, !l.isEmpty else { return .orderedSame }
        let maxCount = max(r.count, l.count)

        for i in 0..<maxCount {
            let rVal = i < r.count ? r[i] : 0
            let lVal = i < l.count ? l[i] : 0
            if rVal > lVal { return .orderedDescending }
            if rVal < lVal { return .orderedAscending }
        }

        return .orderedSame
    }
}
