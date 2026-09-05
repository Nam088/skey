import AppKit
import ApplicationServices
import Foundation
import os.lock

// MARK: - AppCategory

public enum AppCategory: Int8, Sendable {
    case developerTool, webBrowser, electronOrChat, spotlight, nativeApp
}

// MARK: - AppFocusObserver

/// Thread-safe frontmost PID and dynamic AppCategory tracker with 0-allocation RAM cache.
public final class AppFocusObserver {
    public static let shared = AppFocusObserver()

    private var observer: NSObjectProtocol?
    private var lock = os_unfair_lock()
    private var _currentPID: pid_t = 0
    private var _currentBundleID: String?
    private var _currentCategory: AppCategory = .nativeApp
    private var _currentNeedsPerCharacterInjection = true

    private static var cache: [String: AppCategory] = [:]
    private static var cacheLock = os_unfair_lock()

    private static var perCharCache: [String: Bool] = [:]
    private static var perCharCacheLock = os_unfair_lock()

    // MARK: - Dynamic Classification Engine

    public static func category(for bundleID: String?, bundleURL: URL? = nil) -> AppCategory {
        guard let bundleID, !bundleID.isEmpty else { return .nativeApp }
        if bundleID == "com.apple.Spotlight" { return .spotlight }

        // Fast RAM Cache lookup
        os_unfair_lock_lock(&cacheLock)
        if let cached = cache[bundleID] {
            os_unfair_lock_unlock(&cacheLock)
            return cached
        }
        os_unfair_lock_unlock(&cacheLock)

        let url = bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let detected = inspect(bundleURL: url, bundleID: bundleID)

        os_unfair_lock_lock(&cacheLock)
        cache[bundleID] = detected
        os_unfair_lock_unlock(&cacheLock)
        return detected
    }

    private static func inspect(bundleURL: URL?, bundleID: String) -> AppCategory {
        if let url = bundleURL {
            let fm = FileManager.default
            let fw = url.appendingPathComponent("Contents/Frameworks")

            // 1. Electron / CEF / QtWebEngine
            let isElectron = fm.fileExists(atPath: fw.appendingPathComponent("Electron Framework.framework").path) ||
                             fm.fileExists(atPath: fw.appendingPathComponent("Chromium Embedded Framework.framework").path) ||
                             fm.fileExists(atPath: fw.appendingPathComponent("QtWebEngineCore.framework").path) ||
                             fm.fileExists(atPath: url.appendingPathComponent("Contents/Resources/app.asar").path)
            if isElectron { return .electronOrChat }

            // 2. Info.plist inspection (Browser & Code Editor)
            let plistPath = url.appendingPathComponent("Contents/Info.plist")
            if let data = try? Data(contentsOf: plistPath),
               let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] {
                
                if let urls = dict["CFBundleURLTypes"] as? [[String: Any]],
                   urls.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(where: { ["http", "https"].contains($0.lowercased()) }) == true }) {
                    return .webBrowser
                }

                if let docs = dict["CFBundleDocumentTypes"] as? [[String: Any]] {
                    let codeExts: Set<String> = ["swift", "c", "cpp", "h", "py", "rs", "go", "js", "ts", "java", "kt", "sh", "json", "yaml"]
                    let allExts = docs.flatMap { ($0["CFBundleTypeExtensions"] as? [String])?.map { $0.lowercased() } ?? [] }
                    if allExts.contains(where: { ["html", "htm", "xhtml"].contains($0) }) && codeExts.isDisjoint(with: allExts) {
                        return .webBrowser
                    }
                    if !codeExts.isDisjoint(with: allExts) {
                        return .developerTool
                    }
                }
            }
        }

        // 3. Fallback heuristic for virtual / uninstalled bundle IDs
        let id = bundleID.lowercased()
        if ["browser", "chrome", "safari", "firefox", "edge", "yandex"].contains(where: id.contains) { return .webBrowser }
        if ["zalo", "slack", "discord", "teams", "telegram", "notion"].contains(where: id.contains) { return .electronOrChat }
        if ["xcode", "vscode", "terminal", "iterm", "ghostty", "intellij", "warp"].contains(where: id.contains) { return .developerTool }
        return .nativeApp
    }

    // MARK: - Injection Capability Detection

    /// Whether injected text must be delivered one character per `CGEvent` for this app.
    ///
    /// Qt hosts discard any `CGEvent` whose unicode string holds more than one character,
    /// dropping the entire replacement while still applying the backspaces that preceded it.
    /// Measured on TeXstudio 4.9.7 (Qt 6): every replacement of two characters or more was
    /// lost, every single-character one arrived. AppKit and Chromium accept both forms.
    ///
    /// Deliberately kept separate from `AppCategory`: this answers one narrow question about
    /// event delivery, while the category drives recomposition and selection heuristics.
    /// Folding the two would change behaviour for apps that merely happen to embed Qt.
    ///
    /// Defaults to `true` when the bundle cannot be inspected, so an unknown app takes the
    /// slower path that works everywhere rather than the faster one that silently eats text.
    public static func needsPerCharacterInjection(for bundleID: String?, bundleURL: URL? = nil) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return true }

        os_unfair_lock_lock(&perCharCacheLock)
        if let cached = perCharCache[bundleID] {
            os_unfair_lock_unlock(&perCharCacheLock)
            return cached
        }
        os_unfair_lock_unlock(&perCharCacheLock)

        let url = bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let detected = containsQtRuntime(bundleURL: url)

        os_unfair_lock_lock(&perCharCacheLock)
        perCharCache[bundleID] = detected
        os_unfair_lock_unlock(&perCharCacheLock)
        return detected
    }

    /// Detects a bundled Qt runtime, shipped either as `Qt*.framework` or as `libQt*.dylib`.
    /// Both layouts are common, so the directory is scanned by name rather than probing a
    /// fixed list of paths.
    private static func containsQtRuntime(bundleURL: URL?) -> Bool {
        guard let bundleURL else { return true }
        let frameworks = bundleURL.appendingPathComponent("Contents/Frameworks")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: frameworks.path) else {
            // No Frameworks directory at all means no bundled Qt. A plain AppKit app looks
            // exactly like this, and those were verified to accept multi-character events.
            return false
        }
        return entries.contains { name in
            name.hasPrefix("Qt") || name.hasPrefix("libQt")
        }
    }

    // MARK: - State Accessors

    public var currentPID: pid_t {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentPID
    }

    public var currentBundleID: String? {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentBundleID
    }

    public var currentCategory: AppCategory {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentCategory
    }

    /// Cached answer for the frontmost app. Read on the event tap hot path, so it must never
    /// touch the filesystem: the value is resolved once per app activation.
    public var currentNeedsPerCharacterInjection: Bool {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentNeedsPerCharacterInjection
    }

    private init() {
        if let app = NSWorkspace.shared.frontmostApplication { updateFrontmostApp(app) }
    }

    public func startObserving(onAppChange: @escaping (_ bundleID: String?) -> Void) {
        stopObserving()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.updateFrontmostApp(app)
            onAppChange(app?.bundleIdentifier)
        }
    }

    public func stopObserving() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
    }

    private func updateFrontmostApp(_ app: NSRunningApplication?) {
        guard let app else {
            os_unfair_lock_lock(&lock)
            _currentPID = 0; _currentBundleID = nil; _currentCategory = .nativeApp
            _currentNeedsPerCharacterInjection = true
            os_unfair_lock_unlock(&lock)
            return
        }

        // Classification performs bundle inspection and filesystem I/O. Do it before
        // taking the state lock so readers are never blocked during app activation.
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier
        let category = Self.category(for: bundleID, bundleURL: app.bundleURL)
        let needsPerChar = Self.needsPerCharacterInjection(for: bundleID, bundleURL: app.bundleURL)

        if category == .webBrowser || category == .spotlight {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            _ = AXUIElementSetAttributeValue(appElem, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(appElem, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }

        os_unfair_lock_lock(&lock)
        _currentPID = pid
        _currentBundleID = bundleID
        _currentCategory = category
        _currentNeedsPerCharacterInjection = needsPerChar
        os_unfair_lock_unlock(&lock)
    }
}
